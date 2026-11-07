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
  # navbar badge + the row's button). A derivative passes `role:` (no blob noid).
  def create
    @queue = DownloadQueue.new(session)
    read_item_params
    @result = add_current_item
    warn_if_full

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(download_queue_path) }
    end
  end

  # The modal's Remove asks for a stream by its .turbo_stream path and gets the
  # control swapped back. Every other remove, the queue page's included, is
  # redirected to the queue page: Turbo's Accept header alone asks for a stream
  # on any form, so it cannot tell the two apart.
  def destroy
    @queue = DownloadQueue.new(session)
    read_item_params
    @role ? @queue.remove_derivative(@work_noid, @role) : @queue.remove(@work_noid, @blob_noid)

    if params[:format] == 'turbo_stream'
      render :destroy
    else
      redirect_to download_queue_path, notice: 'Removed from your download queue.'
    end
  end

  def destroy_all
    DownloadQueue.new(session).clear
    redirect_to download_queue_path, notice: 'Download queue cleared.'
  end

  private

    # A derivative's role token doubles as its label when the row sent none.
    def read_item_params
      @work_noid = params[:work_noid].to_s
      @role = params[:role].to_s.presence
      @blob_noid = params[:blob_noid].to_s
      @label = params[:label].to_s.presence || @role&.titleize
    end

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
