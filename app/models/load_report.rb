# frozen_string_literal: true

class LoadReport < ApplicationRecord
  belongs_to :loader, optional: true
  has_many :xml_ingests, dependent: :destroy
  has_many :iptc_ingests, dependent: :destroy
  has_many :multipage_ingests, dependent: :destroy

  # `previewing` (XML loader only) is a pre-run hold: the archive is staged
  # and the first-row preview is rendered, but nothing is enqueued until the
  # librarian confirms (LoadsController#confirm flips it to `pending`). It is
  # neither in-progress (no job is running) nor a final status — the show view
  # branches on `previewing?` and renders the preview instead of the report,
  # so it never reaches the polling path.
  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3, completed_with_warnings: 4, previewing: 5 }

  # Lifecycle predicates used by the show view to decide whether to keep
  # polling (in_progress?) and which empty state to render. A report is
  # in progress until it reaches one of the three terminal statuses
  # (completed / completed_with_warnings / failed).
  def in_progress?
    pending? || processing?
  end

  def terminal?
    !in_progress?
  end

  def start_load
    update!(status: :processing, started_at: Time.current)
  end

  def finish_load
    update!(status: :completed, finished_at: Time.current)
  end

  def finish_with_warnings
    update!(status: :completed_with_warnings, finished_at: Time.current)
  end

  def fail_load
    update!(status: :failed, finished_at: Time.current)
  end

  def total_ingests
    ingest_relations.sum(&:count)
  end

  def completed_ingests
    ingest_relations.sum { |rel| rel.completed.count }
  end

  def warning_ingests
    ingest_relations.sum { |rel| rel.completed_with_warnings.count }
  end

  def failed_ingests
    ingest_relations.sum { |rel| rel.failed.count }
  end

  # Ingests that have reached a terminal per-row state, over the total —
  # the numerator/denominator for the in-progress determinate meter on
  # the show page. "Processed" deliberately counts warnings and failures
  # too: the meter tracks how much work is *finished*, not how much
  # succeeded (the summary tiles already break that down).
  def processed_ingests
    completed_ingests + warning_ingests + failed_ingests
  end

  def progress_percent
    return 0 if total_ingests.zero?

    ((processed_ingests * 100.0) / total_ingests).round
  end

  # Re-finalization is deliberate: UnzipJob creates rows incrementally
  # while streaming the archive, so an early row job can finalize before
  # later rows exist; subsequent calls converge the status (e.g.
  # completed → failed once a late row lands). Don't add an
  # "already terminal" guard here — it breaks that convergence.
  def maybe_finalize!
    status_settled = false
    with_lock do
      return if rows_outstanding?

      if rows_failed?
        fail_load
      elsif rows_warned?
        finish_with_warnings
      else
        finish_load
      end
      status_settled = saved_change_to_status?
    end
    # Outside the lock — bookkeeping, not part of the transaction. Fires
    # only when this call actually moved the status, so a re-trigger with
    # the same outcome (a retried row job after the report settled) stays
    # silent; a genuine correction messages again with the new status.
    return unless status_settled

    notify_creator!
    enqueue_work_completion!
  end

  private

    # The three per-kind ingest tables a report may tally. Summing the
    # counters and finalization predicates over this list keeps
    # maybe_finalize! itself kind-agnostic.
    def ingest_relations
      [iptc_ingests, xml_ingests, multipage_ingests]
    end

    def rows_outstanding?
      ingest_relations.any? { |rel| rel.exists?(status: %i[pending processing]) }
    end

    def rows_failed?
      ingest_relations.any? { |rel| rel.failed.exists? }
    end

    def rows_warned?
      ingest_relations.any? { |rel| rel.completed_with_warnings.exists? }
    end

    # Multipage completion barrier: the one Work behind a multipage report
    # may only be completed (Atlas flips in_progress *and* builds the
    # Work-level METS structMap — the preservation record of page order)
    # once every page row has landed. Riding the status-settle signal gives
    # exactly-once enqueueing; failed reports never complete their Work,
    # leaving in_progress=true as the stuck-deposit operator flag.
    def enqueue_work_completion!
      return unless loader&.multipage?
      return unless completed? || completed_with_warnings?

      CompleteWorkJob.perform_later(id)
    end

    # First system producer for the User Inbox: tell whoever started the
    # load that it reached a terminal state. Pre-inbox rows never recorded
    # a creator — nothing to notify.
    def notify_creator!
      return if creator_nuid.blank?

      SystemMessage.deliver(
        to_nuid: creator_nuid,
        subject: %(Load "#{source_filename}" #{status.humanize.downcase}),
        body:    notification_body
      )
    end

    def notification_body
      counts = "#{completed_ingests} completed, #{warning_ingests} with warnings, #{failed_ingests} failed."
      return counts if loader.blank?

      "#{counts}\nView the report: #{Rails.application.routes.url_helpers.loader_load_path(loader, self)}"
    end
end
