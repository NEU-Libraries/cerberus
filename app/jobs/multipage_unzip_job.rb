# frozen_string_literal: true

# Validate-everything-then-mint for the multipage loader.
#
# Enqueued by LoadsController#confirm once the librarian approves the
# preview. The whole archive becomes ONE Work, so unlike XmlUnzipJob this
# is the enforcement point for the full manifest contract: extraction →
# Contract → XmlValidator all pass before any Atlas call. A forced confirm
# past a blocked preview therefore still cannot mint anything — the
# preview is UX, this job is the guarantee.
#
# Page rows are ALL created before any page job is enqueued. That closes
# the premature-finalize race the XML pipeline tolerates (an early row job
# observing "no rows outstanding" while siblings are uncreated): the
# report settles exactly once, which the CompleteWorkJob barrier rides.
#
# A crash between Work mint and row creation fails the report and leaves
# the Work in_progress: true — by design, that flag is the operator
# visibility for stuck deposits (see /works?in_progress=true).
class MultipageUnzipJob < ApplicationJob
  queue_as :default

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # Linear shape (guard → extract → validate → mint → fan out → rescue)
  # mirrors XmlUnzipJob and reads as one flow; the extra branches are the
  # contract/MODS gates that must all precede the Atlas mint.
  def perform(load_report_id)
    load_report = LoadReport.find(load_report_id)
    return unless load_report.pending?

    load_report.start_load

    extracted = XmlLoader::Paths.extracted_dir(load_report)
    FileUtils.mkdir_p(extracted)
    extracted_names = Set.new
    XmlLoader::Archive.new(XmlLoader::Paths.archive_path(load_report))
                      .extract_all(extracted) { |basename| extracted_names << basename }

    manifest_path = File.join(extracted, 'manifest.xlsx')
    unless File.exist?(manifest_path)
      return structural_failure(load_report, 'No manifest.xlsx was found in the uploaded archive.')
    end

    rows = MultipageLoader::Manifest.new(manifest_path).rows
    return structural_failure(load_report, 'The manifest has a header row but no data rows.') if rows.empty?

    errors = MultipageLoader::Contract.call(rows: rows, present_files: extracted_names)
    return structural_failure(load_report, errors.join(' ')) if errors.any?

    mods_path = File.join(extracted, File.basename(rows.find(&:mods_row?).xml_path))
    mods_errors = XmlValidator.call(xml: File.read(mods_path))
    return structural_failure(load_report, "Invalid MODS: #{mods_errors.join('; ')}") if mods_errors.any?

    work_pid = mint_work(load_report, mods_path)
    fan_out(load_report, rows.select(&:page?), work_pid) if work_pid
  rescue MultipageLoader::Manifest::EmptyError, MultipageLoader::Manifest::HeaderError => e
    structural_failure(load_report, e.message)
  rescue StandardError => e
    Rails.logger.error("MultipageUnzipJob failed for LoadReport #{load_report_id}: #{e.class} #{e.message}")
    LoadReport.find_by(id: load_report_id)&.fail_load
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

    # The one Work this archive becomes. Mint failure is a structural
    # failure (this job never retries, mirroring XmlUnzipJob's rescue), so
    # the idempotency key is single-use.
    def mint_work(load_report, mods_path)
      AtlasRb::Work.create(load_report.parent_collection_id, mods_path,
                           idempotency_key: SecureRandom.uuid).id
    rescue Faraday::Error => e
      structural_failure(load_report, "Could not create the Work in Atlas: #{e.message}")
      nil
    end

    def fan_out(load_report, pages, work_pid)
      ingests = pages.sort_by(&:sequence).map do |row|
        load_report.multipage_ingests.create!(
          source_filename: row.file_name,
          sequence:        row.sequence,
          work_pid:        work_pid,
          idempotency_key: SecureRandom.uuid
        )
      end
      ingests.each { |ingest| MultipageIngestJob.perform_later(ingest.id) }
    end

    # Write a single failed row carrying the manifest-level reason, then
    # finalize so the report reaches a terminal state — same surface as
    # XmlUnzipJob's structural failures.
    def structural_failure(load_report, message)
      load_report.multipage_ingests.create!(
        source_filename: 'manifest.xlsx',
        status:          :failed,
        error_message:   message,
        idempotency_key: SecureRandom.uuid
      )
      load_report.maybe_finalize!
    end
end
