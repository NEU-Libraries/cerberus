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

  before_action :authorize_show!
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
