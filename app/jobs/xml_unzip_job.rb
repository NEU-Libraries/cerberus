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

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  # Linear shape (guard → extract → locate manifest → parse → fan out → rescue)
  # mirrors UnzipJob and reads as one flow; splitting it would scatter the
  # structural-failure handling.
  def perform(load_report_id)
    load_report = LoadReport.find(load_report_id)
    return unless load_report.pending?

    load_report.start_load

    extracted = XmlLoader::Paths.extracted_dir(load_report)
    FileUtils.mkdir_p(extracted)
    XmlLoader::Archive.new(XmlLoader::Paths.archive_path(load_report)).extract_all(extracted)

    manifest_path = File.join(extracted, 'manifest.xlsx')
    unless File.exist?(manifest_path)
      return structural_failure(load_report, 'No manifest.xlsx was found in the uploaded archive.')
    end

    rows = XmlLoader::Manifest.new(manifest_path).rows
    return structural_failure(load_report, 'The manifest has a header row but no data rows.') if rows.empty?

    fan_out(load_report, rows)
  rescue XmlLoader::Manifest::EmptyError, XmlLoader::Manifest::HeaderError => e
    structural_failure(load_report, e.message)
  rescue StandardError => e
    Rails.logger.error("XmlUnzipJob failed for LoadReport #{load_report_id}: #{e.class} #{e.message}")
    LoadReport.find_by(id: load_report_id)&.fail_load
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

    # Two-phase fan-out (mirrors MultipageUnzipJob#fan_out): create every row
    # before enqueuing any job, so an early row job can't finalize the report
    # before later rows exist. `rows` is already fully materialized, so this is
    # a trivial split — only XmlIngest records accumulate, no archive bytes.
    def fan_out(load_report, rows)
      ingests = rows.map { |row| create_row(load_report, row) }
      ingests.zip(rows).each do |ingest, row|
        XmlIngestJob.perform_later(ingest.id, row.to_h.transform_keys(&:to_s))
      end
    end

    def create_row(load_report, row)
      load_report.xml_ingests.create!(
        source_filename: row.identifier.presence || row.file_name.presence || row.xml_path.to_s,
        idempotency_key: SecureRandom.uuid
      )
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
