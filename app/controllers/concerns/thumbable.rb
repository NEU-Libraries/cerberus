# frozen_string_literal: true

module Thumbable
  extend ActiveSupport::Concern

  # Persist a user-uploaded poster on any resource (Work / Collection /
  # Community) from the edit form's Thumbnail file input. The upload is a local
  # image, so mint the open (display-capped) TIFF from it via the same IiifImageCreator
  # chain the deposit pipeline uses, turn it into the thumbnail URLs and the
  # preview's size and placeholder, and write them through the dedicated
  # /thumbnails endpoint. Thumbnails are machine-set Delegate URIs with their own
  # endpoint — distinct from the descriptive and permissions writes — so they go
  # via the dedicated set_thumbnails endpoint, not the metadata PATCH.
  def apply_thumbnail(id)
    file = params[:thumbnail]
    return if file.blank?

    image = IiifImageCreator.call(path: file.tempfile.path.presence || file.path)
    AtlasRb::Resource.set_thumbnails(id, **ThumbnailCreator.call(image: image))
  end
end
