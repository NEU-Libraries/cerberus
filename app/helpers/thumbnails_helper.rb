# frozen_string_literal: true

# Guards the one thing a stored thumbnail can do to a page that renders it,
# supplies the poster an audio or video Work's player shows without one, and
# reserves the Work preview's frame with a blurred stand-in.
# See docs/derivatives.md.
module ThumbnailsHelper
  AV_PLACEHOLDER = 'av-placeholder.svg'
  PREVIEW_FRAME = 'max-width: 100%; padding: 4px; border: 1px solid rgba(0,0,0,0.2);'
  BASE64 = %r{\A[A-Za-z0-9+/]+=*\z}

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

  # HAML renders a nil attribute as an empty one, so absent keys are left out.
  def preview_image_attributes(width, height, placeholder)
    width = width.to_i
    height = height.to_i
    return { style: PREVIEW_FRAME } unless width.positive? && height.positive?

    # Without `height: auto`, `max-width` squashes a narrowed image.
    style = "#{PREVIEW_FRAME} height: auto;"
    if placeholder.to_s.match?(BASE64)
      # Unclipped, the padding keeps a blurred ring round the finished image.
      style += " background-image: url(#{preview_placeholder_uri(width, height, placeholder)}); " \
               'background-size: cover; background-clip: content-box; background-origin: content-box;'
    end
    { width: width, height: height, style: style }
  end

  # Base64 keeps the URI free of anything that could end `url()`.
  def preview_placeholder_uri(width, height, placeholder)
    view_height = (500.0 * height / width).round
    svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 500 #{view_height}'>" \
          "<filter id='b' color-interpolation-filters='sRGB'><feGaussianBlur stdDeviation='18'/>" \
          "<feComponentTransfer><feFuncA type='discrete' tableValues='1 1'/></feComponentTransfer></filter>" \
          "<image width='500' height='#{view_height}' preserveAspectRatio='none' filter='url(#b)' " \
          "href='data:image/jpeg;base64,#{placeholder}'/></svg>"
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
