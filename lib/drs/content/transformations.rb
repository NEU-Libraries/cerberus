module Drs
  module Content
    module Transformations

      def self.image_to_thumbnail(parent) 
        desc = "Thumbnail for #{parent.pid}"

        assert_parent_is(parent, ImageMasterFile) 
        child = instantiate_with_metadata(parent, "#{parent.title} thumbnail", desc, ImageThumbnailFile) 
        parent.transform_datastream :content, { thumb: { size: '100x100>', datastream: 'thumbnail' } }
        child.add_file(parent.thumbnail.content, 'content', thumbnailify(parent.label)) 
        child.save! ? child : false
      end

      def self.pdf_to_thumbnail(parent)
        desc = "Thumbnail for #{parent.pid}"

        assert_parent_is(parent, PdfFile) 
        child = instantiate_with_metadata(parent, "#{parent.title} thumbnail", desc, ImageThumbnailFile) 
        parent.transform_datastream :content, { thumb: { size: '100x100>', datastream: 'thumbnail' } } 
        child.add_file(parent.thumbnail.content, 'content', thumbnailify(parent.label)) 
        child.save! ? child : false 
      end

      def self.docx_to_pdf(parent)
        assert_parent_is(parent, MswordFile) 
        child = instantiate_with_metadata(parent, "#{parent.title} pdf", PdfFile) 
        parent.transform_datastream :content, { to_pdf: { format: 'pdf', datastream: 'pdf', datastream: 'thumbnail'} }, processor: 'document'
        child.add_file(parent.to_pdf.content, 'content', change_file_extension(parent.label, 'pdf'))
        child.save! ? child : false
      end

      private

        def self.instantiate_with_metadata(parent, title, desc, klass)
          a = klass.new(pid: Sufia::Noid.namespaceize(Sufia::IdService.mint)) 
          a.title       = title
          a.keywords    = parent.keywords.flatten unless parent.keywords.nil?
          a.description = desc 
          a.depositor   = parent.depositor 
          a.core_record = ::NuCoreFile.find(parent.core_record.pid)
          a.identifier  = a.pid
          a.rightsMetadata.content = parent.rightsMetadata.content 
          return a
        end

        def self.change_file_extension(label, ext) 
          a = label.split('.')
          a[-1] = ext 
          return a.join(".") 
        end

        def self.thumbnailify(label) 
          a = label.split(".") 
          a[0] = "#{a[0]}_thumb" 
          a[-1] = 'png'
          return a.join(".")
        end

        def self.assert_parent_is(parent, klass) 
          if !parent.instance_of? klass 
            raise ParentMismatchError.new(parent, klass)
          end
        end

        class ParentMismatchError < StandardError 
          def initialize(parent, klass) 
            super "Expected parent to be an instance of #{klass}, but it was an instance of #{parent.class}" 
          end
        end  
    end
  end
end