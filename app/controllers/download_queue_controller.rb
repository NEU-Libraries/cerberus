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

  # Add a content Blob or an IIIF derivative rendition (turbo-stream swaps the
  # navbar badge + the row's button). A derivative passes `role:` (no blob noid),
  # which doubles as its label in the swapped-in "In queue" state.
  def create
    @queue = DownloadQueue.new(session)
    @work_noid = params[:work_noid].to_s
    @role = params[:role].to_s.presence
    @blob_noid = params[:blob_noid].to_s
    @result = add_current_item
    warn_if_full

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(download_queue_path) }
    end
  end

  def destroy
    queue = DownloadQueue.new(session)
    if params[:role].present?
      queue.remove_derivative(params[:work_noid].to_s, params[:role].to_s)
    else
      queue.remove(params[:work_noid].to_s, params[:blob_noid].to_s)
    end
    redirect_to download_queue_path, notice: 'Removed from your download queue.'
  end

  def destroy_all
    DownloadQueue.new(session).clear
    redirect_to download_queue_path, notice: 'Download queue cleared.'
  end

  private

    # Add the request's item — a derivative rendition (by role) or a Blob (by noid).
    def add_current_item
      @role ? @queue.add_derivative(@work_noid, @role) : @queue.add(@work_noid, @blob_noid)
    end

    def warn_if_full
      flash.now[:alert] = "Your download queue is full (max #{DownloadQueue::MAX})." if @result == :full
    end

    # Bare-noid → display title, one batch round-trip (mirrors SetResolver).
    def titles_for(work_noids)
      return {} if work_noids.empty?

      AtlasRb::Resource.find_many(work_noids).index_by { |digest| digest['noid'] }
    end

    # work_noid → { blob_noid or role => label }, so the page can name each
    # queued file. A Blob is keyed by its noid, a rendition by its role token.
    def labels_for(work_noids)
      work_noids.index_with do |noid|
        AtlasRb::Work.assets(noid, nuid: viewer_nuid)
                     .each_with_object({}) { |asset, labels| label_asset(labels, asset) }
      rescue Faraday::Error, JSON::ParserError
        {}
      end
    end

    def label_asset(labels, asset)
      label = asset.label.presence || asset[:use]
      key = asset[:uri].present? ? asset[:role] : asset.noid
      labels[key] = label if key.present?
    end
end
