# frozen_string_literal: true

class MasterJp2 < ApplicationService
  def initialize(path:)
    @path = path
  end

  def call
    img = Vips::Image.new_from_file(@path, **load_options)
    uuid = Time.now.to_f.to_s.gsub!('.', '')
    img.jp2ksave(File.join(Rails.application.config.x.cerberus.derivatives_root, "#{uuid}.jp2"))
    "#{Rails.application.config.iiif_host}/iiif/3/#{uuid}.jp2"
  end

  private

    # PDFs rasterize through vips' poppler loader, first page by default
    # (page: 0). 150 dpi makes a letter page ~1275px wide — crisp for the
    # 500px preview tile without an oversized JP2. Image loaders don't
    # accept dpi, so only pass it when the source really is a PDF.
    def load_options
      pdf? ? { dpi: 150 } : {}
    end

    def pdf?
      Marcel::MimeType.for(Pathname.new(@path)) == 'application/pdf'
    end
end
