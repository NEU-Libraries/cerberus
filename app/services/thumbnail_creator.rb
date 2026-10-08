# frozen_string_literal: true

class ThumbnailCreator < ApplicationService
  def initialize(base:)
    @base = base
  end

  # `base` is the open copy, already capped at IiifImageCreator::OPEN_CAP wide,
  # so `max` is the preview. A fixed `500,` 400s on a source narrower than the
  # cap, because IIIF 3 refuses to upscale without `^`.
  def call
    {
      thumbnail:    "#{@base}/full/!85,85/0/default.jpg",
      thumbnail_2x: "#{@base}/full/!170,170/0/default.jpg",
      preview:      "#{@base}/full/max/0/default.jpg"
    }
  end
end
