# frozen_string_literal: true

# The per-item unit of a multipage load: validate the item's MODS, mint the one
# Work the item becomes, stamp work_pid onto its page rows, and fan out a page
# job each. See docs/people-and-routing.md and docs/ingest.md.
#
# The mint idempotency key is passed in, so a retry never double-mints, and a
# bad item fails only its own pages rather than the batch.
class MultipageItemJob < ApplicationJob
  queue_as :default

  # Exhausted retries fail just this item's rows, leaving the rest of the batch
  # alone; the report finalizes once every item settles.
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
    # work_pid means a prior attempt minted and stamped, and a failed row means a
    # prior attempt rejected the item.
    return if rows.where.not(work_pid: nil).exists? || rows.exists?(status: :failed)

    mods_path = File.join(XmlLoader::Paths.extracted_dir(report), mods_basename)
    mods_errors = XmlValidator.call(xml: File.read(mods_path))
    return self.class.fail_item_rows(report, item_index, "Invalid MODS: #{mods_errors.join('; ')}") if mods_errors.any?

    mint_and_fan_out(report, item_index, mods_path, work_idempotency_key)
  end

  # Marks every still-open row of one item failed and settles the report.
  # update_all keeps it cheap for an item with many pages, so updated_at is set
  # explicitly.
  def self.fail_item_rows(report, item_index, message)
    report.multipage_ingests.where(item_index: item_index).where.not(status: :failed)
          .update_all(status: MultipageIngest.statuses[:failed], error_message: message, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    report.maybe_finalize!
  end

  private

    def mint_and_fan_out(report, item_index, mods_path, work_idempotency_key)
      work_pid = AtlasRb::Work.create(report.parent_collection_id, mods_path,
                                      idempotency_key: work_idempotency_key).id
      Sentinel.apply_default(report.parent_collection_id, work_pid)
      page_rows = report.multipage_ingests.where(item_index: item_index).where.not(sequence: nil)
      # One UPDATE stamps every page row of the item, so updated_at is set explicitly.
      page_rows.update_all(work_pid: work_pid, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      page_rows.find_each { |ingest| MultipageIngestJob.perform_later(ingest.id) }
    end
end
