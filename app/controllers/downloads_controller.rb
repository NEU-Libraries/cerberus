# frozen_string_literal: true

class DownloadsController < ApplicationController
  include ActionController::Live

  before_action :authorize_show!

  def show
    id   = params[:id]
    nuid = Current.nuid
    blob = AtlasRb::Blob.find(id, nuid: nuid)

    response.headers['Content-Type'] = blob.mime_type
    response.headers['Content-Disposition'] =
      ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: blob.filename)

    AtlasRb::Blob.content(id, nuid: nuid) { |chunk| response.stream.write(chunk) }
  ensure
    response.stream.close
  end
end
