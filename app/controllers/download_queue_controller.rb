# frozen_string_literal: true

# Manages the per-session Download Queue (add/remove/clear) and renders the
# queue page. Anon-capable (the queue lives in the session, DB-backed). The
# streamed ZIP itself is QueueDownloadsController (needs ActionController::Live).
class DownloadQueueController < ApplicationController
  # The queue page: items grouped by work, with titles + per-file labels for
  # display and a "Download all" / "Clear" affordance. Both lookups are batched
  # / one-per-work; the queue is small (user-curated).
  def show
    @queue = DownloadQueue.new(session)
    work_noids = @queue.items.pluck('w').uniq
    @titles = titles_for(work_noids)
    @labels = labels_for(work_noids)
  end

  # Add a content Blob (turbo-stream swaps the navbar badge + the row's button).
  def create
    @queue = DownloadQueue.new(session)
    @work_noid = params[:work_noid].to_s
    @blob_noid = params[:blob_noid].to_s
    @result = @queue.add(@work_noid, @blob_noid)

    flash.now[:alert] = "Your download queue is full (max #{DownloadQueue::MAX})." if @result == :full

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(download_queue_path) }
    end
  end

  def destroy
    DownloadQueue.new(session).remove(params[:work_noid].to_s, params[:blob_noid].to_s)
    redirect_to download_queue_path, notice: 'Removed from your download queue.'
  end

  def destroy_all
    DownloadQueue.new(session).clear
    redirect_to download_queue_path, notice: 'Download queue cleared.'
  end

  private

    # Bare-noid → display title, one batch round-trip (mirrors SetResolver).
    def titles_for(work_noids)
      return {} if work_noids.empty?

      AtlasRb::Resource.find_many(work_noids).index_by { |digest| digest['noid'] }
    end

    # work_noid → { blob_noid => label }, so the page can name each queued file.
    def labels_for(work_noids)
      work_noids.index_with do |noid|
        AtlasRb::Work.assets(noid, nuid: current_user&.nuid)
                     .to_h { |asset| [asset.noid, asset.label.presence || asset[:use]] }
      rescue Faraday::Error, JSON::ParserError
        {}
      end
    end
end
