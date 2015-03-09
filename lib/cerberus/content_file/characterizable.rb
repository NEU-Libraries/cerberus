# Code from Sufia mostly handles getting things to characterize via FITS correctly,
# but does leave the requisite pieces scattered across three different modules/classes.
# This encapsulates that.

module Cerberus
  module ContentFile
    module Characterizable
      extend ActiveSupport::Concern

      # Required Sufia code
      include Cerberus::CoreFile::MimeTypes
      include Cerberus::CoreFile::Characterization

      included do
        around_save :characterize_if_changed
      end

      def pdf?
        self.class.pdf_mime_types.include? self.mime_type
      end

      def image?
        self.class.image_mime_types.include? self.mime_type
      end

      def video?
        self.class.video_mime_types.include? self.mime_type
      end

      def audio?
        self.class.audio_mime_types.include? self.mime_type
      end

      def zip?
        self.class.zip_mime_types.include? self.mime_type
      end

      def characterize
        self.characterization.ng_xml = self.content.extract_metadata
        self.filename = self.label
        save
      end
    end

    private

      def characterize_if_changed
        content_changed = self.content.changed?
        yield
        Cerberus::Application::Queue.push(AtomisticCharacterizationJob.new(self.pid)) if content_changed
      end
  end
end
