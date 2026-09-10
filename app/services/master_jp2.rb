# frozen_string_literal: true

# Mints the two JP2s the gated-derivative model needs from one source: a capped
# open display copy and a gated full-resolution copy. The `open-` / `gated-`
# filename prefix is what the delegate gates on, and a plain hyphen (not an
# `open/…` subpath) keeps the identifier slash-free, so signed-URL paths carry
# no `%2F` that could desync from the delegate. See docs/downloads.md.
class MasterJp2 < ApplicationService
  # Capping the open copy is what keeps `full/max` on an `open-` identifier safe
  # by construction: the master's pixels are not in that file.
  OPEN_CAP = 500

  Result = Struct.new(:open_base, :gated_base, keyword_init: true)

  def initialize(path:)
    @path = path
  end

  def call
    # Normalise to 3-band sRGB before encoding, or a grayscale or CMYK source
    # yields a JP2 whose header parses — info.json succeeds — but whose
    # codestream Cantaloupe cannot decode, making every render 501.
    img = Vips::Image.new_from_file(@path, **load_options).colourspace(:srgb)
    Result.new(
      open_base:  mint(capped(img), 'open'),
      gated_base: mint(img,         'gated')
    )
  end

  private

    def mint(img, prefix)
      filename = "#{prefix}-#{SecureRandom.uuid}.jp2"
      img.jp2ksave(File.join(Rails.application.config.x.cerberus.derivatives_root, filename))
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
