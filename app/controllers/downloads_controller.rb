# frozen_string_literal: true

class DownloadsController < ApplicationController
  include ActionController::Live

  before_action :authorize_show!

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
