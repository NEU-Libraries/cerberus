# frozen_string_literal: true

require 'tempfile'

# Per-row XML loader job. One is enqueued per manifest row by XmlUnzipJob.
#
# Two modes, decided by the row (v1's edit-vs-create determination):
#
# - update: the row carries an identifier (a v2 NOID, which *is* the Atlas
#   resource id), so we replace the existing Work's MODS via Work.update.
# - create: the row carries a File Name and no identifier, so we mint a new
#   Work seeded with the bundled MODS, stage the content file, and hand off to
#   IngestDispatch (ContentCreationJob plus per-type enrichment: thumbnails
#   for images/PDFs, PDF renditions for Word/PowerPoint) — the same pipeline
#   a single-file deposit uses.
#
# Idempotent + retryable, mirroring IptcIngestJob: permanent problems (missing
# MODS, invalid MODS, missing content, bad embargo) finalize the row :failed
# inline; anything transient escapes to retry_on and, on exhaustion, marks the
# row :failed so the parent LoadReport can still finalize.
class XmlIngestJob < ApplicationJob
  queue_as :default

  class EmbargoError < StandardError; end

  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    ingest = XmlIngest.find_by(id: job.arguments.first)
    next if ingest.nil? || ingest.completed? || ingest.completed_with_warnings? || ingest.failed?

    ingest.update!(
      status:        :failed,
      error_message: "Failed after #{job.executions} attempts (#{exception.class}: #{exception.message})"
    )
    ingest.load_report&.maybe_finalize!
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # The linear flow (guard → resolve row → read+validate MODS → update/create →
  # embargo → finalize) reads as one idempotency story; splitting it would
  # scatter the per-row failure handling.
  def perform(xml_ingest_id, row)
    ingest = XmlIngest.find(xml_ingest_id)
    return if terminal?(ingest)

    ingest.update!(status: :processing)

    identifier = row['identifier'].presence
    xml_path   = row['xml_path'].presence
    file_name  = row['file_name'].presence

    if identifier.nil? && file_name.nil?
      return finalize_failure(ingest, 'Row has neither an identifier (update) nor a File Name (create).')
    end
    return finalize_failure(ingest, 'Row has no MODS XML File Path.') if xml_path.nil?

    mods = read_mods(ingest, xml_path)
    return finalize_failure(ingest, "MODS XML file '#{xml_path}' was not found in the archive.") if mods.nil?

    errors = XmlValidator.call(xml: mods)
    return finalize_failure(ingest, "Invalid MODS: #{errors.join('; ')}") if errors.any?

    work_pid = identifier ? update_work(ingest, identifier, mods) : create_work(ingest, mods, file_name)
    return finalize_failure(ingest, "Content file '#{file_name}' was not found in the archive.") if work_pid.nil?

    apply_embargo(work_pid, row)
    finalize_success(ingest)
  rescue EmbargoError => e
    finalize_failure(ingest, e.message)
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

    def terminal?(ingest)
      ingest.completed? || ingest.completed_with_warnings? || ingest.failed?
    end

    def uploads_root
      Rails.application.config.x.cerberus.uploads_root
    end

    def read_mods(ingest, xml_path)
      path = File.join(XmlLoader::Paths.extracted_dir(ingest.load_report), File.basename(xml_path))
      File.exist?(path) ? File.read(path) : nil
    end

    # Full MODS replacement on the existing Work. Naturally idempotent — a
    # retry re-applies the same document. work_pid (= the NOID) is recorded so
    # the dashboard can link to the Work.
    def update_work(ingest, noid, mods)
      with_mods_file(mods) { |path| AtlasRb::Work.update(noid, path) }
      ingest.update!(work_pid: noid)
      noid
    end

    # New Work from a bundled content file + MODS. Returns nil if the named
    # content file is absent (a permanent, no-retry failure). The work_pid
    # guard + Atlas idempotency_key make a retry converge without duplicates.
    def create_work(ingest, mods, file_name)
      return ingest.work_pid if ingest.work_pid.present?

      content_path = File.join(XmlLoader::Paths.extracted_dir(ingest.load_report), File.basename(file_name))
      return nil unless File.exist?(content_path)

      work = with_mods_file(mods) do |path|
        AtlasRb::Work.create(ingest.load_report.parent_collection_id, path, idempotency_key: ingest.idempotency_key)
      end
      ingest.update!(work_pid: work.id)

      staged = stage_content(work.id, content_path)
      enqueue_content_jobs(work.id, staged, file_name, ingest.idempotency_key)
      work.id
    end

    def stage_content(work_pid, content_path)
      dir = File.join(uploads_root, work_pid.to_s)
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, File.basename(content_path))
      # Rename on same FS, streaming copy + unlink across FS. Never read+write.
      FileUtils.mv(content_path, dest) unless File.exist?(dest)
      dest
    end

    def enqueue_content_jobs(work_pid, staged_path, file_name, idempotency_key)
      IngestDispatch.call(work_id: work_pid, staged_path: staged_path,
                          original_filename: file_name, idempotency_key: idempotency_key)
    end

    # Embargo applies in either mode when the row opts in. A bad/missing date
    # is a permanent failure (raised, caught in #perform) — matching v1, which
    # refused to embargo without a valid YYYY-MM-DD release date.
    def apply_embargo(work_pid, row)
      return unless row['embargoed'].to_s.strip.casecmp?('true')

      date = row['embargo_date'].to_s.strip
      unless date.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        raise EmbargoError, 'Embargoed rows must include an Embargo Date of the form YYYY-MM-DD.'
      end

      AtlasRb::Work.metadata(work_pid, { permissions: { embargo: date } })
    end

    def with_mods_file(mods)
      Tempfile.create(['loader_mods', '.xml']) do |f|
        f.write(mods)
        f.flush
        return yield(f.path)
      end
    end

    def finalize_success(ingest)
      # The warnings channel (completed_with_warnings) is shared with IPTC and
      # left unpopulated here — the natural signal (a no-op update whose new
      # MODS equals the existing) needs a raw-MODS read-back Atlas doesn't
      # expose today. Reserved, not blocking.
      ingest.update!(status: :completed)
      ingest.load_report.maybe_finalize!
    end

    def finalize_failure(ingest, error_message)
      ingest.update!(status: :failed, error_message: error_message)
      ingest.load_report.maybe_finalize!
    end
end
