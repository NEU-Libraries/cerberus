# frozen_string_literal: true

# Final step of a multipage load: tell Atlas each whole Work is complete.
# AtlasRb::Work.complete flips in_progress to false *and* builds the
# Work-level METS structMap (the preservation record of page order), so it
# must fire only after every page FileSet of that Work exists. LoadReport's
# status-settle signal enqueues this exactly once per report; a report carries
# many Works (one per item), so this completes each independently.
class CompleteWorkJob < ApplicationJob
  queue_as :default

  # Safe to retry: Work.complete is idempotent server-side (re-completing an
  # already-complete Work is a no-op re-save), and each Work is re-checked
  # against Atlas before completing, so a retry that re-runs the loop converges.
  retry_on Faraday::Error, attempts: 3, wait: :polynomially_longer

  def perform(load_report_id)
    report = LoadReport.find(load_report_id)
    return unless report.terminal?

    report.multipage_ingests.where.not(work_pid: nil).distinct.pluck(:work_pid).each do |work_pid|
      complete_work(report, work_pid)
    end
  end

  private

    def complete_work(report, work_pid)
      rows = report.multipage_ingests.where(work_pid: work_pid)
      # A page of this item failed — leave the Work in_progress (the
      # stuck-deposit operator flag) rather than complete a Work we can't
      # vouch for. Sibling items are unaffected.
      return if rows.exists?(status: :failed)

      expected = rows.where.not(sequence: nil).count
      actual   = positioned_page_count(work_pid)
      return AtlasRb::Work.complete(work_pid) if actual == expected

      report_mismatch(report, work_pid, expected, actual)
    end

    def positioned_page_count(work_pid)
      AtlasRb::Work.file_sets(work_pid).count { |fs| fs['position'].present? }
    end

    # Invariant breach: every page row of this Work reads completed, but Atlas
    # disagrees on the page count. Leave the Work in_progress (the
    # stuck-deposit operator flag) and tell the creator rather than complete a
    # Work we can't vouch for.
    def report_mismatch(report, work_pid, expected, actual)
      Rails.logger.error(
        "CompleteWorkJob: LoadReport #{report.id} expected #{expected} page FileSets " \
        "on #{work_pid}, Atlas lists #{actual} — not completing"
      )
      return if report.creator_nuid.blank?

      SystemMessage.deliver(
        to_nuid: report.creator_nuid,
        subject: %(Load "#{report.source_filename}" needs attention),
        body:    "The load finished, but Work #{work_pid} lists #{actual} page(s) where " \
                 "#{expected} were expected, so it was left incomplete. " \
                 'Contact a repository administrator before re-running the load.'
      )
    end
end
