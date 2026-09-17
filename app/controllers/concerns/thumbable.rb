# frozen_string_literal: true

module Thumbable
  extend ActiveSupport::Concern

  include AtlasResourceType

  # Persist a user-uploaded poster on any resource (Work / Collection /
  # Community) from the edit form's Thumbnail file input. The upload is a local
  # image, so mint the open (display-capped) JP2 from it via the same MasterJp2
  # chain the deposit pipeline uses, turn that IIIF base into the thumbnail /
  # thumbnail_2x / preview URL trio, and write them through the dedicated
  # /thumbnails endpoint. Thumbnails are machine-set Delegate URIs with their own
  # endpoint — distinct from the descriptive and permissions writes — so they go
  # via the declared resource class's set_thumbnails, not the metadata PATCH.
  def apply_thumbnail(id)
    file = params[:thumbnail]
    return if file.blank?

    base = MasterJp2.call(path: file.tempfile.path.presence || file.path).open_base
    atlas_class.set_thumbnails(id, **ThumbnailCreator.call(base: base))
  end
end
