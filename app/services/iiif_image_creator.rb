# frozen_string_literal: true

# Mints the two pyramidal TIFFs the gated-derivative model needs from one
# source: a capped open display copy and a gated full-resolution copy. The
# `open-` / `gated-` filename prefix is what the delegate gates on, and a plain
# hyphen (not an `open/…` subpath) keeps the identifier slash-free, so
# signed-URL paths carry no `%2F` that could desync from the delegate. See
# docs/downloads.md.
class IiifImageCreator < ApplicationService
  # Capping the open copy is what keeps `full/max` on an `open-` identifier safe
  # by construction: the original's pixels are not in that file.
  OPEN_CAP = 500

  # Every pyramid level must be tiled, or Java2dProcessor decodes a whole level
  # per deep-zoom tile. docs/derivatives.md has the measurements behind Q90.
  TIFF_OPTIONS = { tile: true, pyramid: true, compression: :jpeg, Q: 90, tile_width: 256, tile_height: 256 }.freeze

  # Kept: the ICC profile. Dropped: everything docs/derivatives.md lists.
  STRIPPED_METADATA = %w[exif-data xmp-data iptc-data].freeze

  # The preview's blurred stand-in on the Work page. Capping the longest edge,
  # not the width, keeps a tall image under Atlas's 2048-character limit: an
  # oversized value 422s the whole thumbnail write. See docs/derivatives.md.
  PLACEHOLDER_EDGE = 16
  PLACEHOLDER_LIMIT = 2048

  # `open_width` and `open_height` are the open copy's own size, which is the
  # preview's, since the preview asks for that copy at `full/max`.
  Result = Struct.new(:open_base, :gated_base, :open_width, :open_height, :open_placeholder, keyword_init: true)

  # Base64 of a tiny JPEG of `img`, or nil when it would not fit the limit.
  def self.placeholder(img)
    scale = [PLACEHOLDER_EDGE.to_f / [img.width, img.height].max, 1].min
    encoded = Base64.strict_encode64(img.resize(scale).jpegsave_buffer(Q: 50, strip: true))
    encoded if encoded.length <= PLACEHOLDER_LIMIT
  end

  def initialize(path:)
    @path = path
  end

  def call
    # Rotate the pixels upright before capping. Cantaloupe honours the TIFF
    # orientation tag tiffsave copies from the source, so a rotated photo capped
    # before rotation serves narrower than the cap.
    img = Vips::Image.new_from_file(@path, **load_options).autorot
    # Normalise to three-band sRGB: JPEG compression takes neither CMYK nor an
    # alpha channel reliably, so transparency flattens onto white.
    img = img.colourspace(:srgb)
    img = img.flatten(background: [255, 255, 255]) if img.has_alpha?
    img = img.mutate { |m| STRIPPED_METADATA.each { |field| m.remove!(field) } }
    open = capped(img)
    Result.new(
      open_base:        mint(open, 'open'),
      gated_base:       mint(img,  'gated'),
      open_width:       open.width,
      open_height:      open.height,
      open_placeholder: self.class.placeholder(open)
    )
  end

  private

    def mint(img, prefix)
      filename = "#{prefix}-#{SecureRandom.uuid}.tif"
      img.tiffsave(File.join(Rails.application.config.x.cerberus.derivatives_root, filename), **TIFF_OPTIONS)
      "#{Rails.application.config.iiif_host}/iiif/3/#{filename}"
    end

    # Cap the WIDTH, not the longest edge: the `preview` Delegate asks for
    # width 500, and a longest-edge cap leaves portrait sources narrower. Never
    # upscale a narrower source.
    def capped(img)
      scale = OPEN_CAP.to_f / img.width
      scale < 1 ? img.resize(scale) : img
    end

    # Image loaders don't accept dpi, so only pass it when the source really is
    # a PDF.
    def load_options
      pdf? ? { dpi: 150 } : {}
    end

    def pdf?
      File.exist?(@path) && Marcel::MimeType.for(Pathname.new(@path)) == 'application/pdf'
    end
end
