# Code from Sufia mostly handles getting things to characterize via FITS correctly,
# but does leave the requisite pieces scattered across three different modules/classes.
# This encapsulates that.

module Cerberus
  module ContentFile
    module Characterizable
      extend ActiveSupport::Concern

      include Cerberus::Characterization

      included do
        around_save :characterize_if_changed
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
