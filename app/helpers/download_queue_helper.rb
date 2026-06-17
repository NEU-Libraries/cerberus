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
end
