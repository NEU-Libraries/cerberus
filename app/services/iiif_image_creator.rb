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

  # Every pyramid level must be tiled, or Cantaloupe's Java2dProcessor decodes a
  # whole level to serve one deep-zoom region. docs/derivatives.md has the
  # measurements behind JPEG at Q90.
  TIFF_OPTIONS = { tile: true, pyramid: true, compression: :jpeg, Q: 90, tile_width: 256, tile_height: 256 }.freeze

  Result = Struct.new(:open_base, :gated_base, keyword_init: true)

  def initialize(path:)
    @path = path
  end

  def call
    # Normalise to three-band sRGB: JPEG compression takes neither CMYK nor an
    # alpha channel reliably, so transparency flattens onto white.
    img = Vips::Image.new_from_file(@path, **load_options).colourspace(:srgb)
    img = img.flatten(background: [255, 255, 255]) if img.has_alpha?
    Result.new(
      open_base:  mint(capped(img), 'open'),
      gated_base: mint(img,         'gated')
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
