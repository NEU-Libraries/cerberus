# frozen_string_literal: true

class LoadReport < ApplicationRecord
  belongs_to :loader, optional: true
  has_many :xml_ingests, dependent: :destroy
  has_many :iptc_ingests, dependent: :destroy

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
    xml_ingests.count + iptc_ingests.count
  end

  def completed_ingests
    xml_ingests.completed.count + iptc_ingests.completed.count
  end

  def warning_ingests
    xml_ingests.completed_with_warnings.count + iptc_ingests.completed_with_warnings.count
  end

  def failed_ingests
    xml_ingests.failed.count + iptc_ingests.failed.count
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

  def maybe_finalize!
    with_lock do
      # A retried row job can land here after the report already finalized;
      # bail rather than re-finalize (and double-send the inbox note below).
      return if completed? || completed_with_warnings? || failed?
      return if iptc_ingests.exists?(status: %i[pending processing]) ||
                xml_ingests.exists?(status: %i[pending processing])

      if iptc_ingests.failed.exists? || xml_ingests.failed.exists?
        fail_load
      elsif iptc_ingests.completed_with_warnings.exists? ||
            xml_ingests.completed_with_warnings.exists?
        finish_with_warnings
      else
        finish_load
      end
    end
    # Outside the lock — the notification is bookkeeping, not part of the
    # finalization transaction. Early returns above skip it.
    notify_creator!
  end

  private

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
