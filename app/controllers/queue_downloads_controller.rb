# frozen_string_literal: true

# Streams the Download Queue as one ZIP. Dedicated controller because
# ActionController::Live streams every action (same reason as
# SetDownloadsController / DownloadsController). Anon-capable — the queue and
# its per-item permission re-check (QueueZipPacker → Work.assets/Blob.content)
# carry the same gating as a direct download.
class QueueDownloadsController < ApplicationController
  include ActionController::Live
  include ZipKit::RailsStreaming

  def show
    queue = DownloadQueue.new(session)
    return redirect_to(download_queue_path, alert: 'Your download queue is empty.') if queue.empty?

    packer = QueueZipPacker.new(items: queue.items, nuid: current_user&.nuid)
    zip_kit_stream(filename: zip_filename) { |zip| packer.pack(zip) }
  end

  private

    def zip_filename
      "download-queue-#{Time.current.strftime('%Y%m%d')}.zip"
    end
end
