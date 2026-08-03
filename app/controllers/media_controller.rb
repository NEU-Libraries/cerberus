# frozen_string_literal: true

# Seekable, inline A/V byte serving for the in-page video.js player. The
# download twin is DownloadsController (attachment, no Range); this one honours
# HTTP Range so the browser can seek.
#
# The bytes live in Atlas, which serves byte ranges via Blob.content(range:).
# Under ActionController::Live the response commits on the
# first stream write, so the 206 status + Content-Range must be set BEFORE
# streaming — we compute them from the client's Range + the blob size (MediaRange)
# rather than relaying Atlas's post-stream headers (too late), and forward the
# same Range to Atlas so only the requested slice crosses the wire.
class MediaController < ApplicationController
  include ProxyUnbuffered
  include RecordsImpressions
  include DerivativesHelper

  before_action :authorize_show!
  before_action :deny_if_work_embargoed!, only: :show
  before_action :record_media_impression, only: :show

  def show
    blob = AtlasRb::Blob.find(params[:id])
    # blob['size'] is the byte size; blob.size is Hash#size (key count) on a Mash.
    range = MediaRange.parse(request.headers['Range'], blob['size'])
    set_media_headers(blob, range)

    AtlasRb::Blob.content(params[:id], range: range && request.headers['Range']) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end

  private

    # Streaming IS consumption for A/V, so an embargo has to reach this route as
    # well as the download twin — withholding the Downloads section while serving
    # the bytes here withholds nothing. `authorize_show!` cannot stand in for it:
    # an embargoed Work is deliberately READABLE (its metadata stays public), so
    # the read gate passes and only this check refuses.
    #
    # The route is addressed by Blob, and a Blob's own permissions do not carry
    # the containing Work's embargo, so the Work has to be resolved first —
    # the same second round-trip DownloadsController makes.
    def deny_if_work_embargoed!
      work_id = AtlasRb::Blob.work(params[:id], nuid: effective_user&.nuid)
      return if work_id.blank?

      deny_if_embargoed!(work_id)
    end

    def set_media_headers(blob, range)
      response.headers['Content-Type'] = blob.mime_type
      response.headers['Content-Disposition'] =
        ActionDispatch::Http::ContentDisposition.format(disposition: 'inline', filename: blob.filename)
      response.headers['Accept-Ranges'] = 'bytes'
      set_length_headers(blob, range)
    end

    def set_length_headers(blob, range)
      if range
        response.status = 206
        response.headers['Content-Range'] = range.content_range
        response.headers['Content-Length'] = range.length.to_s
      elsif blob['size']
        response.headers['Content-Length'] = blob['size'].to_s
      end
    end
end
