# frozen_string_literal: true

module ApplicationHelper
  def application_version
    VERSION
  end

  def iiif_url(uuid)
    # Supports staging, production etc.
    if Rails.application.config.iiif_host.present?
      "http://#{Rails.application.config.iiif_host}:8182/iiif/3/#{uuid}.jp2"
    else
      "http://#{request.host}:8182/iiif/3/#{uuid}.jp2"
    end
  end
end
