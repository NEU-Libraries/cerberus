# frozen_string_literal: true

# Streams the Download Queue as one ZIP. Dedicated controller because
# ActionController::Live streams every action (same reason as
# SetDownloadsController / DownloadsController). Anon-capable — the queue and
# its per-item permission re-check (QueueZipPacker → Work.assets/Blob.content)
# carry the same READ gating as a direct download. Read is not the whole gate:
# an embargoed Work is readable on purpose, so the packer also needs the
# caller's bypass right to decide whether withheld content may be included.
class QueueDownloadsController < ApplicationController
  include ProxyUnbuffered
  include ZipKit::RailsStreaming

  def show
    queue = DownloadQueue.new(session)
    return redirect_to(download_queue_path, alert: 'Your download queue is empty.') if queue.empty?

    packer = QueueZipPacker.new(items: queue.items, nuid: effective_user&.nuid,
                                ability: current_ability, bypass_embargo: bypass_embargo?)
    zip_kit_stream(filename: zip_filename) { |zip| packer.pack(zip) }
  end

  private

    # The CALLER's right — see SetDownloadsController for why that matters, and
    # why the caller is `effective_user`: during View-as the archive has to be
    # built as the identity being stood in for, matching the single-file routes.
    def bypass_embargo?
      effective_user.present? && effective_user.can_bypass_embargo?
    end

    def zip_filename
      "download-queue-#{Time.current.strftime('%Y%m%d')}.zip"
    end
end
