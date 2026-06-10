# frozen_string_literal: true

# Final step of a multipage load: tell Atlas the Work is whole.
# AtlasRb::Work.complete flips in_progress to false *and* builds the
# Work-level METS structMap (the preservation record of page order), so it
# must fire only after every page FileSet exists. LoadReport's
# status-settle signal enqueues this exactly once; the count check below is
# a belt-and-suspenders verification against Atlas itself before the
# irreversible-feeling step.
class CompleteWorkJob < ApplicationJob
  queue_as :default

  # Safe to retry: Work.complete is idempotent server-side (re-completing
  # an already-complete Work is a no-op re-save).
  retry_on Faraday::Error, attempts: 3, wait: :polynomially_longer

  def perform(load_report_id)
    report = LoadReport.find(load_report_id)
    return unless report.completed? || report.completed_with_warnings?

    work_pid = report.multipage_ingests.where.not(work_pid: nil).pick(:work_pid)
    return if work_pid.blank?

    expected = report.multipage_ingests.where.not(sequence: nil).count
    actual   = positioned_page_count(work_pid)
    return AtlasRb::Work.complete(work_pid) if actual == expected

    report_mismatch(report, work_pid, expected, actual)
  end

  private

    def positioned_page_count(work_pid)
      AtlasRb::Work.file_sets(work_pid).count { |fs| fs['position'].present? }
    end

    # Invariant breach: every page row reads completed, but Atlas disagrees
    # on the page count. Leave the Work in_progress (the stuck-deposit
    # operator flag) and tell the creator rather than complete a Work we
    # can't vouch for.
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
