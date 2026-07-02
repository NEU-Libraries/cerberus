# frozen_string_literal: true

# Mints the two JP2s the gated-derivative model needs from one source: a capped
# display copy (thumbnails/preview, served openly) and a full-resolution copy
# (S/M/L downloads + deep-zoom, served only behind the delegate). Both go to the
# single derivatives root Cantaloupe reads, distinguished by an `open-` /
# `gated-` filename prefix — the signal the delegate gates on (serve `open-*`
# freely, require a credential for `gated-*`). A plain hyphen prefix (not an
# `open/…` subpath) keeps the identifier slash-free, so signed-URL paths carry
# no `%2F` that could desync between Cerberus and the delegate.
class MasterJp2 < ApplicationService
  # The open (display) JP2 is capped to the `preview` hero WIDTH (its `500,`
  # request): thumbnails and preview are all downscales of it, and nothing on
  # the open pipe needs more. Capping here keeps `full/max` on an `open-`
  # identifier safe by construction — the master's pixels aren't in that file.
  OPEN_CAP = 500

  Result = Struct.new(:open_base, :gated_base, keyword_init: true)

  def initialize(path:)
    @path = path
  end

  def call
    img = Vips::Image.new_from_file(@path, **load_options)
    Result.new(
      open_base:  mint(capped(img), 'open'),
      gated_base: mint(img,         'gated')
    )
  end

  private

    # One derivatives root; the `open-`/`gated-` filename prefix is what the
    # delegate gates on, and it rides through into the IIIF identifier.
    def mint(img, prefix)
      filename = "#{prefix}-#{SecureRandom.uuid}.jp2"
      img.jp2ksave(File.join(Rails.application.config.x.cerberus.derivatives_root, filename))
      "#{Rails.application.config.iiif_host}/iiif/3/#{filename}"
    end

    # Cap the WIDTH at OPEN_CAP so the `preview` Delegate's `500,` (width-500)
    # request serves without upscaling in every orientation — a longest-edge
    # cap would leave portrait sources narrower than 500. Never upscale a
    # narrower source (a pure downscale, matching DerivativeCreator's posture).
    def capped(img)
      scale = OPEN_CAP.to_f / img.width
      scale < 1 ? img.resize(scale) : img
    end

    # PDFs rasterize through vips' poppler loader, first page by default
    # (page: 0). 150 dpi makes a letter page ~1275px wide — crisp for the
    # 500px preview tile without an oversized JP2. Image loaders don't
    # accept dpi, so only pass it when the source really is a PDF.
    def load_options
      pdf? ? { dpi: 150 } : {}
    end

    def pdf?
      File.exist?(@path) && Marcel::MimeType.for(Pathname.new(@path)) == 'application/pdf'
    end
end
