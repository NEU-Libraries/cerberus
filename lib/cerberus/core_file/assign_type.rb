module Cerberus
  module CoreFile
    module AssignType
      include MimeHelper
      include TempFileStorage

      def instantiate_appropriate_content_object(file_path, original_filename="")

        mime_type = extract_mime_type(file_path, original_filename)
        ext = extract_extension(mime_type)
        result = hash_mime_type(mime_type)

        if is_image?(result)
          self.canonical_class = "ImageMasterFile"
        elsif is_epub?(result)
          self.canonical_class = "EpubFile"
        elsif is_pdf?(result)
          self.canonical_class = "PdfFile"
        elsif is_audio?(result)
          self.canonical_class = "AudioFile"
        elsif is_video?(result)
          self.canonical_class = "VideoFile"
        elsif is_msword?(ext)
          self.canonical_class = "MswordFile"
        elsif is_msexcel?(ext)
          self.canonical_class = "MsexcelFile"
        elsif is_msppt?(ext)
          self.canonical_class = "MspowerpointFile"
        elsif is_texty?(result)
          self.canonical_class = "TextFile"
        else
          self.canonical_class = "ZipFile"
        end

        hsh = dcmi_type

        self.dc_type = hsh[:dc]
        self.mods_type = hsh[:mods]

        self.save! ? self : Rails.logger.warn("Failed to update #{self.pid}'s dcmi type")
      end

      def canonical_class_from_file(file, original_filename="")
        file_path = copy_file_to_tmp(file)
        mime_type = extract_mime_type(file_path, original_filename)
        ext = extract_extension(mime_type)
        result = hash_mime_type(mime_type)

        if is_image?(result)
          canonical_class = "ImageMasterFile"
        elsif is_epub?(result)
          canonical_class = "EpubFile"
        elsif is_pdf?(result)
          canonical_class = "PdfFile"
        elsif is_audio?(result)
          canonical_class = "AudioFile"
        elsif is_video?(result)
          canonical_class = "VideoFile"
        elsif is_msword?(ext)
          canonical_class = "MswordFile"
        elsif is_msexcel?(ext)
          canonical_class = "MsexcelFile"
        elsif is_msppt?(ext)
          canonical_class = "MspowerpointFile"
        elsif is_texty?(result)
          canonical_class = "TextFile"
        else
          canonical_class = "ZipFile"
        end
        FileUtils.rm(file_path)
        return canonical_class
      end

      # Tag core with a DCMI noun based on the sort of content object created.
      def dcmi_type
        hsh = Hash.new

        if !self.canonical_class.blank?
          if self.canonical_class.constantize == VideoFile
            hsh[:dc] = "Moving Image"
            hsh[:mods] = "moving image"
          elsif self.canonical_class.constantize == ImageMasterFile
            hsh[:dc] = "Image"
            hsh[:mods] = "still image"
          elsif [TextFile, PdfFile, MswordFile, EpubFile].include? self.canonical_class.constantize
            hsh[:dc] = "Text"
            hsh[:mods] = "text"
          elsif self.canonical_class.constantize == AudioFile
            hsh[:dc] = "Audio"
            hsh[:mods] = "sound recording"
          elsif self.canonical_class.constantize == MsexcelFile
            hsh[:dc] = "Dataset"
            hsh[:mods] = "software, multimedia"
          elsif self.canonical_class.constantize == MspowerpointFile
            hsh[:dc] = "Interactive Resource"
            hsh[:mods] = "software, multimedia"
          elsif self.canonical_class.constantize == ZipFile
            hsh[:dc] = "Collection"
            hsh[:mods] = "software, multimedia"
          end
        end

        return hsh
      end

      private

        # Takes a string like "image/jpeg ; encoding=binary", generated by FileMagic.
        # And turns it into the hash {raw_type: 'image', sub_type: 'jpeg', encoding: 'binary'}
        def hash_mime_type(mime_type)
          result = {}
          result[:raw_type] = mime_type.split("/").first.strip
          result[:sub_type] = mime_type.split("/").last.strip
          return result
        end

        def is_epub?(fm_hash)
          return fm_hash[:sub_type].include?("epub")
        end

        def is_image?(fm_hash)
          return fm_hash[:raw_type] == 'image'
        end

        def is_pdf?(fm_hash)
          return fm_hash[:sub_type] == 'pdf'
        end

        def is_video?(fm_hash)
          return fm_hash[:raw_type] == 'video'
        end

        def is_audio?(fm_hash)
          return fm_hash[:raw_type] == 'audio'
        end

        def is_msword?(ext)
          file_extension = ['docx', 'doc'].include? ext
          return file_extension
        end

        def is_msexcel?(ext)
          file_extension = ['xls', 'xlsx', 'xlw'].include? ext
          return file_extension
        end

        def is_msppt?(ext)
          file_extension = ['ppt', 'pptx', 'pps', 'ppsx'].include? ext
          return file_extension
        end

        def is_texty?(fm_hash)
          return fm_hash[:raw_type] == 'text'
        end

    end
  end
end
