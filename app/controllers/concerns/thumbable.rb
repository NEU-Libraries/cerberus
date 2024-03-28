# frozen_string_literal: true

module Thumbable
  extend ActiveSupport::Concern

  def add_thumbnail(permitted_params)
    file = params[:thumbnail]
    return if file.blank?

    permitted_params[:thumbnail] = ThumbnailCreator.call(
      path: file.tempfile.path.presence || file.path
    ) # UUID
  end
end
