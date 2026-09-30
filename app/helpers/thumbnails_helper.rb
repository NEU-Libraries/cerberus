# frozen_string_literal: true

# Guards the one thing a stored thumbnail can do to a page that renders it, and
# supplies the poster an audio or video Work's player shows without one.
# See docs/derivatives.md.
module ThumbnailsHelper
  AV_PLACEHOLDER = 'av-placeholder.svg'

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

  # The player's poster: the Work's own, else the placeholder mark. Only the
  # show page's player uses the mark; a list or gallery tile without a
  # thumbnail keeps the type icon, as every other type does.
  def av_poster_src(preview)
    preview.presence || image_path(AV_PLACEHOLDER)
  end
end
