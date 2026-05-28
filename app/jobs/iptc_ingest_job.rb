# frozen_string_literal: true

# Per-image IPTC ingest job. One of these is enqueued per archive entry
# by UnzipJob. Parses IPTC + dimensions, builds a MODS doc, mints an
# Atlas Work, stages the JPEG, and hands off to ContentCreationJob +
# IiifAssetsJob. Each step is idempotent so a retry from any point
# converges without duplicating Works or files.
#
# v1 sizing is preserved by computing per-image Rational scale factors
# pinned to the longest source dimension (600px and 1400px caps,
# clamped to 1.0 so sub-target sources are not upscaled). Medium
# derivative is omitted to match v1's `m = 0`.
class IptcIngestJob < ApplicationJob
  queue_as :default

  # Transient-failure retry policy. The in-method rescues below catch
  # known *permanent* exceptions (bad IPTC data, missing source file)
  # and finalize the IptcIngest :failed inline — those never reach
  # this retry handler. Anything else (DB blip, Atlas timeout, FS
  # transient) escapes the method, ActiveJob/Solid Queue retries up
  # to 3x with polynomial backoff, and on exhaustion the block below
  # marks the row :failed so the parent LoadReport can finalize
  # (otherwise the row would stay :processing forever and
  # maybe_finalize! would never fire).
  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    iptc_ingest_id = job.arguments.first
    ingest = IptcIngest.find_by(id: iptc_ingest_id)
    next if ingest.nil?
    next if ingest.completed? || ingest.completed_with_warnings? || ingest.failed?

    ingest.update!(
      status:        :failed,
      error_message: "Failed after #{job.executions} attempts (#{exception.class}: #{exception.message})"
    )
    ingest.load_report&.maybe_finalize!
  end

  def perform(iptc_ingest_id)
    ingest = IptcIngest.find(iptc_ingest_id)
    return if terminal?(ingest)

    ingest.update!(status: :processing)

    source = current_source_path(ingest)
    return finalize_failure(ingest, "Source file missing at #{source}") unless File.exist?(source)

    extracted = Iptc::Extractor.call(path: source)
    mods = Iptc::MODSBuilder.call(iptc: extracted.tags)

    work_pid = ensure_work(ingest, mods.xml)
    staged_path = stage(ingest, work_pid)

    ContentCreationJob.perform_later(work_pid, staged_path, ingest.source_filename, ingest.idempotency_key)
    IiifAssetsJob.perform_later(work_pid, staged_path, derivative_widths: widths_for(extracted))

    finalize_success(ingest, mods.warnings)
  rescue Iptc::MODSBuilder::MissingRequiredField => e
    finalize_failure(ingest, "Missing required IPTC field: #{e.message}")
  rescue Iptc::Extractor::UnsupportedIptcType => e
    finalize_failure(ingest, e.message)
  end

  private

    def terminal?(ingest)
      ingest.completed? || ingest.completed_with_warnings? || ingest.failed?
    end

    def uploads_root
      Rails.application.config.x.cerberus.uploads_root
    end

    def extracted_path(ingest)
      File.join(uploads_root,
                'load_reports',
                ingest.load_report_id.to_s,
                'extracted',
                ingest.source_filename)
    end

    def staged_path(ingest, work_pid = ingest.work_pid)
      File.join(uploads_root, work_pid.to_s, ingest.source_filename)
    end

    def current_source_path(ingest)
      # After a successful stage, the file lives at staged_path; on
      # first run it's at extracted_path. Pick whichever exists so
      # retries find the file no matter where the previous run left it.
      ingest.work_pid.present? ? staged_path(ingest) : extracted_path(ingest)
    end

    def ensure_work(ingest, mods_xml)
      return ingest.work_pid if ingest.work_pid.present?

      work = Tempfile.create(['ingest_mods', '.xml']) do |f|
        f.write(mods_xml)
        f.flush
        AtlasRb::Work.create(
          ingest.load_report.parent_collection_id,
          f.path,
          idempotency_key: ingest.idempotency_key
        )
      end
      ingest.update!(work_pid: work.id)
      work.id
    end

    def stage(ingest, work_pid)
      dir = File.join(uploads_root, work_pid.to_s)
      FileUtils.mkdir_p(dir)
      dest = staged_path(ingest, work_pid)
      # FileUtils.mv is rename-if-same-fs, streaming-copy + unlink if cross-fs.
      # Never read+write — that would slurp the JPEG into Ruby memory.
      FileUtils.mv(extracted_path(ingest), dest) unless File.exist?(dest)
      dest
    end

    def widths_for(result)
      longest = result.longest_side
      return { small: 1.0, large: 1.0 } if longest <= 0

      # Float (not Rational) — ActiveJob's default argument serializer
      # rejects Rational. The DerivativeCreator handles both Float and
      # Rational identically (Numeric ≤ 1 → pct:N), and Float coming
      # from Rational.to_f preserves precision well enough for our
      # IIIF percentages (3-digit rounding in DerivativeCreator).
      {
        small: Rational([600,  longest].min, longest).to_f,
        large: Rational([1400, longest].min, longest).to_f
      }
    end

    def finalize_success(ingest, warnings)
      if warnings.any?
        ingest.update!(status: :completed_with_warnings, warnings: warnings)
      else
        ingest.update!(status: :completed)
      end
      ingest.load_report.maybe_finalize!
    end

    def finalize_failure(ingest, error_message)
      ingest.update!(status: :failed, error_message: error_message)
      ingest.load_report.maybe_finalize!
    end
end
