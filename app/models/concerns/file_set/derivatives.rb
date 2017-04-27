module FileSet
  module Derivatives

    extend ActiveSupport::Concern

    included do
      # placeholder for updates to derivatives services
    end

    def create_derivatives
      case original_file.mime_type
      when *self.class.pdf_mime_types
        Hydra::Derivatives::PdfDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'png', size: '338x493', object: self }])
      when *self.class.office_document_mime_types
        Hydra::Derivatives::DocumentDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'jpg', size: '200x150>', object: self }])
      when *self.class.video_mime_types
        Hydra::Derivatives::VideoDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'png', object: self }])
      when *self.class.image_mime_types
        Hydra::Derivatives::ImageDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'png', size: '200x150>', object: self }])
      end
    end

  end
end
