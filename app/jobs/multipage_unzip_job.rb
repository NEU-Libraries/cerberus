# frozen_string_literal: true

# Lightweight, local-only scaffolding step for the multipage loader.
#
# Enqueued by LoadsController#confirm. A manifest concatenates many items;
# this job does NO Atlas calls — it extracts the archive, parses and groups
# rows into items (ItemSet), and contract-validates each item locally. For a
# contract-valid item it creates the item's pending page rows; for an invalid
# item it records one failed summary row (skip-bad, ingest-valid). It then
# fans out one MultipageItemJob per valid item — that job owns the per-item
# Atlas work (MODS validation, Work mint, page fan-out).
#
# Keeping every Atlas round-trip out of this job is deliberate: a 1000-item
# sheet must not become one long network-bound job whose mid-run crash strands
# half-minted Works. A crash here fails a report that has minted nothing.
#
# Two-phase fan-out: ALL page rows across ALL items are created before any
# item job is enqueued, so the report's full row set exists before any row can
# reach a terminal state — maybe_finalize! never observes a premature
# empty-outstanding set, and the CompleteWorkJob barrier rides the single
# status-settle.
class MultipageUnzipJob < ApplicationJob
  queue_as :default

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  # Linear shape (guard → extract → parse → group → scaffold) mirrors the
  # other unzip jobs and reads as one flow; the branches are structural gates.
  def perform(load_report_id)
    load_report = LoadReport.find(load_report_id)
    return unless load_report.pending?

    load_report.start_load

    extracted = XmlLoader::Paths.extracted_dir(load_report)
    FileUtils.mkdir_p(extracted)
    present_files = Set.new
    XmlLoader::Archive.new(XmlLoader::Paths.archive_path(load_report))
                      .extract_all(extracted) { |basename| present_files << basename }

    manifest_path = File.join(extracted, 'manifest.xlsx')
    unless File.exist?(manifest_path)
      return structural_failure(load_report, 'No manifest.xlsx was found in the uploaded archive.')
    end

    rows = MultipageLoader::Manifest.new(manifest_path).rows
    return structural_failure(load_report, 'The manifest has a header row but no data rows.') if rows.empty?

    items = MultipageLoader::ItemSet.call(rows: rows)
    return structural_failure(load_report, 'The manifest produced no items.') if items.empty?

    scaffold_and_fan_out(load_report, items, present_files)
  rescue MultipageLoader::Manifest::EmptyError, MultipageLoader::Manifest::HeaderError => e
    structural_failure(load_report, e.message)
  rescue StandardError => e
    Rails.logger.error("MultipageUnzipJob failed for LoadReport #{load_report_id}: #{e.class} #{e.message}")
    LoadReport.find_by(id: load_report_id)&.fail_load
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

    # Phase 1 (create every row) fully precedes Phase 2 (enqueue), so the
    # report's whole row set exists before any item/page job runs. A clean item
    # gets page rows and an item job; an invalid one gets a failed summary row.
    def scaffold_and_fan_out(load_report, items, present_files)
      valid = []
      items.each do |item|
        errors = MultipageLoader::Contract.call(item: item, present_files: present_files)
        if errors.empty?
          create_page_rows(load_report, item)
          valid << item
        else
          create_failed_item_row(load_report, item, errors)
        end
      end

      valid.each { |item| enqueue_item_job(load_report, item) }
      # Settles the all-invalid report (no item job was enqueued); a no-op in
      # the mixed/valid case while page rows are still pending.
      load_report.maybe_finalize!
    end

    def enqueue_item_job(load_report, item)
      MultipageItemJob.perform_later(
        load_report.id, item.index, File.basename(item.xml_path),
        work_idempotency_key: SecureRandom.uuid
      )
    end

    def create_page_rows(load_report, item)
      item.pages.each do |row|
        load_report.multipage_ingests.create!(
          item_index:      item.index,
          source_filename: row.file_name,
          sequence:        row.sequence,
          idempotency_key: SecureRandom.uuid
        )
      end
    end

    # One failed summary row per skipped item, labelled so the report names
    # which item failed and why.
    def create_failed_item_row(load_report, item, errors)
      load_report.multipage_ingests.create!(
        item_index:      item.index,
        source_filename: item.label,
        status:          :failed,
        error_message:   errors.join(' '),
        idempotency_key: SecureRandom.uuid
      )
    end

    # Write a single failed row carrying the manifest-level reason, then
    # finalize so the report reaches a terminal state — same surface as the
    # other unzip jobs' structural failures.
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
