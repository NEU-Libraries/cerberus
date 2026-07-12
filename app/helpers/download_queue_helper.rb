# frozen_string_literal: true

# View helpers for the session Download Queue — the navbar badge count/label
# (mirrors MessagesHelper#unread_messages_count) and per-row membership.
module DownloadQueueHelper
  def download_queue
    @download_queue ||= DownloadQueue.new(session)
  end

  delegate :count, to: :download_queue, prefix: true

  def download_queue_aria_label
    count = download_queue_count
    count.positive? ? "Download queue, #{count} item#{'s' unless count == 1}" : 'Download queue'
  end

  def download_queue_includes?(work_noid, blob_noid)
    download_queue.include?(work_noid, blob_noid)
  end

  def download_queue_includes_derivative?(work_noid, use)
    download_queue.include_derivative?(work_noid, use)
  end

  # Stable DOM id for a row's queue control, shared by _queue_button and the
  # create/destroy turbo_stream so an add/remove swaps the right node. Blob rows
  # key on the globally-unique blob noid; derivative rows have none, so they key
  # on work + a slugged use (a use like "Small Image" isn't a valid id fragment).
  def queue_control_id(work_noid, blob_noid: nil, use: nil)
    blob_noid.present? ? "queue-control-#{blob_noid}" : "queue-control-#{work_noid}-#{use.to_s.parameterize}"
  end
end
