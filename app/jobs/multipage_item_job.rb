# frozen_string_literal: true

# The per-item, Atlas-bound unit of a multipage load — one job per
# contract-valid item. MultipageUnzipJob has already created the item's
# pending page rows (grouped by item_index) and validated its structure
# locally; this job owns everything that touches the network:
#
#   1. validate the item's MODS (XmlValidator — the XSD work, isolated per
#      item; Kataba caches the schema across items);
#   2. mint the one Work this item becomes;
#   3. stamp work_pid onto the item's page rows;
#   4. fan out a MultipageIngestJob per page.
#
# Isolating each item here is the point: a transient Atlas failure retries a
# single item (the mint idempotency key is passed in, so a retry never
# double-mints), and a bad item fails only its own pages — neither aborts the
# batch.
class MultipageItemJob < ApplicationJob
  queue_as :default

  # Exhausted retries (Atlas unreachable) fail just this item's rows, leaving
  # the rest of the batch alone; the report finalizes once every item settles.
  retry_on Faraday::Error, attempts: 3, wait: :polynomially_longer do |job, exception|
    load_report_id, item_index, = job.arguments
    report = LoadReport.find_by(id: load_report_id)
    next if report.nil?

    fail_item_rows(report, item_index,
                   "Could not create the Work in Atlas after #{job.executions} attempts " \
                   "(#{exception.class}: #{exception.message})")
  end

  def perform(load_report_id, item_index, mods_basename, work_idempotency_key:)
    report = LoadReport.find(load_report_id)
    rows = report.multipage_ingests.where(item_index: item_index)
    return if report.failed? || rows.none?
    # Already processed: page rows are created pending with no work_pid, so a
    # work_pid present means a prior attempt minted + stamped (retry after
    # success), and a failed row means a prior attempt rejected the item.
    return if rows.where.not(work_pid: nil).exists? || rows.exists?(status: :failed)

    mods_path = File.join(XmlLoader::Paths.extracted_dir(report), mods_basename)
    mods_errors = XmlValidator.call(xml: File.read(mods_path))
    return self.class.fail_item_rows(report, item_index, "Invalid MODS: #{mods_errors.join('; ')}") if mods_errors.any?

    mint_and_fan_out(report, item_index, mods_path, work_idempotency_key)
  end

  # Mark every still-open row of one item failed and settle the report. Used by
  # the MODS-invalid path and the retry-exhaustion handler; update_all keeps it
  # cheap for items with many pages, so updated_at is set explicitly.
  def self.fail_item_rows(report, item_index, message)
    report.multipage_ingests.where(item_index: item_index).where.not(status: :failed)
          .update_all(status: MultipageIngest.statuses[:failed], error_message: message, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    report.maybe_finalize!
  end

  private

    def mint_and_fan_out(report, item_index, mods_path, work_idempotency_key)
      work_pid = AtlasRb::Work.create(report.parent_collection_id, mods_path,
                                      idempotency_key: work_idempotency_key).id
      page_rows = report.multipage_ingests.where(item_index: item_index).where.not(sequence: nil)
      page_rows.update_all(work_pid: work_pid, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      page_rows.find_each { |ingest| MultipageIngestJob.perform_later(ingest.id) }
    end
end
