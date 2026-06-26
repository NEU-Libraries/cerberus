# frozen_string_literal: true

class DownloadsController < ApplicationController
  include ActionController::Live
  include RecordsImpressions

  before_action :authorize_show!
  # After authorize_show!, so only authorized downloads are recorded; runs
  # before the Live stream opens (the job resolves blob → Work off-request).
  before_action :record_download_impression, only: :show

  def show
    blob = AtlasRb::Blob.find(params[:id])

    response.headers['Content-Type'] = blob.mime_type
    response.headers['Content-Disposition'] =
      ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: blob.filename)

    AtlasRb::Blob.content(params[:id]) { |chunk| response.stream.write(chunk) }
  ensure
    response.stream.close
  end
end
