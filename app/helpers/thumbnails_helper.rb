# frozen_string_literal: true

# Guards the one thing a stored thumbnail can do to a page that renders it, and
# supplies the placeholder an audio or video Work shows without one.
# See docs/derivatives.md.
module ThumbnailsHelper
  AV_PLACEHOLDER = 'av-placeholder.svg'
  AV_CLASSIFICATIONS = %w[Audio Video].freeze

  # A stored thumbnail value that is safe to hand to image_tag, or nil.
  #
  # Atlas writes every thumbnail as an absolute IIIF URL, and image_tag passes a
  # URL through untouched. A relative value instead resolves through Propshaft,
  # which RAISES Propshaft::MissingAssetError on a miss rather than rendering a
  # broken image. Every caller renders whatever Solr happens to hold — a catalog
  # row, a Set row, an association tile — so one malformed value would take down
  # a whole page rather than degrade its own tile. Callers treat nil as "no
  # thumbnail" and fall back to the type icon.
  def renderable_thumbnail(src)
    value = src.to_s
    value.start_with?('http://', 'https://', '//') ? value : nil
  end

  # The placeholder mark's path for an audio or video Work's Solr document, or
  # nil for any other. The test is the Work's content classification, so a tile
  # needs no read beyond the document it already has.
  def av_placeholder_src(document)
    image_path(AV_PLACEHOLDER) if Array(document['classification_ssim']).intersect?(AV_CLASSIFICATIONS)
  end

  # The player's poster: the Work's own, else the placeholder mark.
  def av_poster_src(preview)
    preview.presence || image_path(AV_PLACEHOLDER)
  end
end
