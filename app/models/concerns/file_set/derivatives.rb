module FileSet
  module Derivatives

    extend ActiveSupport::Concern

    included do
      # placeholder for updates to derivatives services
      # http://pcdm.org/use#IntermediateFile
      directly_contains_one :jp2, through: :files, type: ::RDF::URI('http://pcdm.org/use#IntermediateFile'), class_name: 'Hydra::PCDM::File'
    end

    def create_derivatives
      # case original_file.mime_type
      # when *self.class.pdf_mime_types
      #   Hydra::Derivatives::PdfDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'png', size: '1000x1000>', object: self }])
      # when *self.class.office_document_mime_types
      #   Hydra::Derivatives::DocumentDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'jpg', size: '1000x1000>', object: self }])
      # when *self.class.video_mime_types
      #   Hydra::Derivatives::VideoDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'png', size: '1000x1000>', object: self }])
      # when *self.class.image_mime_types
      #   Hydra::Derivatives::ImageDerivatives.create(self, source: :original_file, outputs: [{ label: :thumbnail, format: 'png', size: '1000x1000>', object: self }])
      # end

      # Make jp2 if image
      if Hydra::Works::FileSet.image_mime_types.include? original_file.mime_type
        fedora_file_path = original_file.fedora_file_path
        jp2_path = Rails.root.join('tmp', "#{SecureRandom.urlsafe_base64}.jp2")
        `convert #{fedora_file_path} -quality 0 #{jp2_path}`
        file = File.new(jp2_path)
        Hydra::Works::AddFileToFileSet.call(self, file, :jp2)
        self.save!
      end
    end

  end
end
