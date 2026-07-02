# frozen_string_literal: true

# Mints the two JP2s the gated-derivative model needs from one source: a
# capped display copy for the OPEN Cantaloupe root (thumbnails/preview,
# served without authorization) and a full-resolution copy for the GATED
# root (S/M/L downloads + deep-zoom, served only behind the delegate). Each
# gets its own random identifier, so the two roots may be the same directory
# in development without colliding.
class MasterJp2 < ApplicationService
  # The open (display) JP2 is capped to the `preview` hero WIDTH (its `500,`
  # request): thumbnails and preview are all downscales of it, and nothing on
  # the open pipe needs more. Capping here is what makes `full/max` on the
  # open Cantaloupe host safe by construction — the master's pixels are not in
  # that file.
  OPEN_CAP = 500

  Result = Struct.new(:open_base, :gated_base, keyword_init: true)

  def initialize(path:)
    @path = path
  end

  def call
    img = Vips::Image.new_from_file(@path, **load_options)
    Result.new(
      open_base:  mint(capped(img), cerberus.open_derivatives_root,  open_host),
      gated_base: mint(img,         cerberus.gated_derivatives_root, gated_host)
    )
  end

  private

    def mint(img, root, host)
      uuid = SecureRandom.uuid
      img.jp2ksave(File.join(root, "#{uuid}.jp2"))
      "#{host}/iiif/3/#{uuid}.jp2"
    end

    # Cap the WIDTH at OPEN_CAP so the `preview` Delegate's `500,` (width-500)
    # request serves without upscaling in every orientation — a longest-edge
    # cap would leave portrait sources narrower than 500. Never upscale a
    # narrower source (a pure downscale, matching DerivativeCreator's posture).
    def capped(img)
      scale = OPEN_CAP.to_f / img.width
      scale < 1 ? img.resize(scale) : img
    end

    def cerberus
      Rails.application.config.x.cerberus
    end

    def open_host
      Rails.application.config.iiif_host
    end

    # Falls back to the open host so a single-Cantaloupe dev stack serves both
    # roots; production points this at the delegate-gated host.
    def gated_host
      cerberus.gated_iiif_host.presence || Rails.application.config.iiif_host
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
