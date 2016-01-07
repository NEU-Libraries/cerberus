module Cerberus
  module ContentFile
    module Characterization
      extend ActiveSupport::Concern
      include ChecksumHelper
      include MimeHelper

      included do
        has_metadata :name => "characterization", :type => FitsDatastream
        delegate_to :characterization, [:format_label, :file_size, :last_modified,
                                        :filename, :original_checksum, :rights_basis,
                                        :copyright_basis, :copyright_note,
                                        :well_formed, :valid, :status_message,
                                        :file_title, :file_author, :page_count,
                                        :file_language, :word_count, :character_count,
                                        :paragraph_count, :line_count, :table_count,
                                        :graphics_count, :byte_order, :compression,
                                        :width, :height, :color_space, :profile_name,
                                        :profile_version, :orientation, :color_map,
                                        :image_producer, :capture_device,
                                        :scanning_software, :exif_version,
                                        :gps_timestamp, :latitude, :longitude,
                                        :character_set, :markup_basis,
                                        :markup_language, :duration, :bit_depth,
                                        :sample_rate, :channels, :data_format, :offset]

        around_save :characterize_if_changed
      end

      ## Extract the metadata from the content datastream and record it in the characterization datastream
      def characterize
        # No longer doing FITS characterization, for the time being
        
        # self.characterization.ng_xml = self.content.extract_metadata
        # self.filename = self.label
        # save
      end

      private

        def characterize_if_changed
          content_changed = self.content.changed?
          yield
          if content_changed
            # Cerberus::Application::Queue.push(AtomisticCharacterizationJob.new(self.pid))
            self.properties.mime_type = extract_mime_type(self.fedora_file_path)
            self.properties.md5_checksum = new_checksum(self.fedora_file_path)
            self.properties.file_size = File.size(self.fedora_file_path).to_s
            self.save!
          end
        end
    end
  end
end
