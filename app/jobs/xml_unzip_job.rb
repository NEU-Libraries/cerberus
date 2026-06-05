# frozen_string_literal: true

# Manifest-driven fan-out for the XML loader — the analogue of UnzipJob.
#
# Enqueued by LoadsController#confirm once the librarian approves the preview.
# Streams the staged archive to disk (large create-mode content files never
# land in a Ruby string — the batch-job memory rule), parses manifest.xlsx,
# and for each data row creates one XmlIngest + enqueues one XmlIngestJob. The
# per-row inputs ride along as a job argument so XmlIngest keeps the same
# schema as IptcIngest and the manifest isn't re-parsed per row.
#
# Manifest-level problems (no manifest, empty, no header row) are surfaced as a
# single failed XmlIngest rather than a silent LoadReport failure, so the
# reason shows up on the same per-row table the run uses.
class XmlUnzipJob < ApplicationJob
  queue_as :default

  def perform(load_report_id)
    load_report = LoadReport.find(load_report_id)
    return unless load_report.pending?

    load_report.start_load

    extracted = XmlLoader::Paths.extracted_dir(load_report)
    FileUtils.mkdir_p(extracted)
    XmlLoader::Archive.new(XmlLoader::Paths.archive_path(load_report)).extract_all(extracted)

    manifest_path = File.join(extracted, 'manifest.xlsx')
    return structural_failure(load_report, 'No manifest.xlsx was found in the uploaded archive.') unless File.exist?(manifest_path)

    rows = XmlLoader::Manifest.new(manifest_path).rows
    return structural_failure(load_report, 'The manifest has a header row but no data rows.') if rows.empty?

    rows.each { |row| enqueue_row(load_report, row) }
  rescue XmlLoader::Manifest::EmptyError, XmlLoader::Manifest::HeaderError => e
    structural_failure(load_report, e.message)
  rescue StandardError => e
    Rails.logger.error("XmlUnzipJob failed for LoadReport #{load_report_id}: #{e.class} #{e.message}")
    LoadReport.find_by(id: load_report_id)&.fail_load
  end

  private

    def enqueue_row(load_report, row)
      ingest = load_report.xml_ingests.create!(
        source_filename: row.identifier.presence || row.file_name.presence || row.xml_path.to_s,
        idempotency_key: SecureRandom.uuid
      )
      XmlIngestJob.perform_later(ingest.id, row.to_h.transform_keys(&:to_s))
    end

    # Write a single failed row carrying the manifest-level reason, then
    # finalize so the report reaches a terminal state. No LoadReport schema
    # change needed — the existing per-row table is the surface.
    def structural_failure(load_report, message)
      load_report.xml_ingests.create!(
        source_filename: 'manifest.xlsx',
        status:          :failed,
        error_message:   message,
        idempotency_key: SecureRandom.uuid
      )
      load_report.maybe_finalize!
    end
end
