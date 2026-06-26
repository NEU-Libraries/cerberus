# frozen_string_literal: true

# Seekable, inline A/V byte serving for the in-page video.js player. The
# download twin is DownloadsController (attachment, no Range); this one honours
# HTTP Range so the browser can seek.
#
# v2's bytes live in Atlas, which now serves byte ranges (atlas_rb 1.8.2
# Blob.content(range:)). Under ActionController::Live the response commits on the
# first stream write, so the 206 status + Content-Range must be set BEFORE
# streaming — we compute them from the client's Range + the blob size (rather
# than relaying Atlas's post-stream headers, which arrive too late) and forward
# the same Range to Atlas so only the requested slice crosses the wire.
class MediaController < ApplicationController
  include ActionController::Live
  include RecordsImpressions

  before_action :authorize_show!
  before_action :record_media_impression, only: :show

  def show
    blob = AtlasRb::Blob.find(params[:id])
    parsed = parse_range(request.headers['Range'], blob.size)
    set_media_headers(blob, parsed)

    AtlasRb::Blob.content(params[:id], range: (parsed && request.headers['Range'])) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end

  private

    def set_media_headers(blob, parsed)
      response.headers['Content-Type'] = blob.mime_type
      response.headers['Content-Disposition'] =
        ActionDispatch::Http::ContentDisposition.format(disposition: 'inline', filename: blob.filename)
      response.headers['Accept-Ranges'] = 'bytes'

      if parsed
        response.status = 206
        response.headers['Content-Range'] = "bytes #{parsed[:start]}-#{parsed[:end]}/#{parsed[:total]}"
        response.headers['Content-Length'] = (parsed[:end] - parsed[:start] + 1).to_s
      else
        response.headers['Content-Length'] = blob.size.to_s if blob.size
      end
    end

    # Parse a single HTTP byte range against the known total. Returns nil for
    # absent/malformed/unsatisfiable ranges (caller then serves the full 200).
    def parse_range(header, total)
      return nil unless total.to_i.positive?
      return nil unless (match = header.to_s.match(/\Abytes=(\d*)-(\d*)\z/))

      start_str, end_str = match[1], match[2]
      if start_str.empty? # bytes=-SUFFIX (final N bytes)
        return nil if end_str.empty?

        start = [total - end_str.to_i, 0].max
        finish = total - 1
      else
        start = start_str.to_i
        finish = end_str.empty? ? total - 1 : [end_str.to_i, total - 1].min
      end
      return nil if start > finish || start >= total

      { start:, end: finish, total: }
    end
end
