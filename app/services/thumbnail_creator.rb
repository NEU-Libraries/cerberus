# frozen_string_literal: true

# The set_thumbnails arguments for one IiifImageCreator::Result.
class ThumbnailCreator < ApplicationService
  def initialize(image:)
    @image = image
  end

  # `open_base` is the open copy, already capped at IiifImageCreator::OPEN_CAP
  # wide, so `max` is the preview. A fixed `500,` 400s on a source narrower than
  # the cap, because IIIF 3 refuses to upscale without `^`.
  def call
    base = @image.open_base
    {
      thumbnail:           "#{base}/full/!85,85/0/default.jpg",
      thumbnail_2x:        "#{base}/full/!170,170/0/default.jpg",
      preview:             "#{base}/full/max/0/default.jpg",
      preview_width:       @image.open_width,
      preview_height:      @image.open_height,
      preview_placeholder: @image.open_placeholder
    }
  end
end
