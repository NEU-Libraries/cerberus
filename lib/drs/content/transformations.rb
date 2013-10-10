module Drs
  module Content
    module Transformations

      # Generates derivatives based off of (an assumed) canonical object. 
      # Cleans up old derivatives as part of the creation process.
      def self.generate_derivatives(parent) 
        purge_thumbnail(parent) 

        if parent.instance_of? ImageMasterFile 
          image_to_thumbnail(parent) 
        elsif parent.instance_of? PdfFile 
          pdf_to_thumbnail(parent) 
        elsif parent.instance_of? MswordFile 
          purge_pdf(parent) 
          word_to_thumbnail(parent) 
        elsif parent.instance_of? MsexcelFile
          Rails.logger.warn "Msexcel file transformations currently unimplemented."
          # purge_csv(parent) 
          # excel_to_csv(parent) 
        end
      end

      def self.image_to_thumbnail(parent)
        image_pdf_to_thumbnail(parent, ImageMasterFile) 
      end

      def self.pdf_to_thumbnail(parent)
        image_pdf_to_thumbnail(parent, PdfFile)
      end

      def self.word_to_pdf(parent)
        assert_parent_is(parent, MswordFile)

        desc = "PDF generated off of Word document at #{parent.pid}" 

        # Create the child object sans content
        child = instantiate_with_metadata(parent, "#{parent.title} pdf", desc, PdfFile)

        # Create the pdf and add it to the child 
        parent.transform_datastream :content, { to_pdf: { format: 'pdf', datastream: 'pdf'} }, processor: 'document'
        child.add_file(parent.pdf.content, 'content', change_file_extension(parent.label, 'pdf'))

        # Return the object if it saves successfully and false otherwise
        child.save! ? child : false
      end


      def self.excel_to_csv(parent) 
        assert_parent_is(parent, MsexcelFile) 

        desc = "CSV generated off of excel document at #{parent.pid}" 

        child = instantiate_with_metadata(parent, "#{parent.title} CSV", desc, TextFile) 

        # Create the csv and add it to the child 
        parent.transform_datastream :content, { excel: { format: 'csv', datastream: 'excel'} }, processor: 'document' 
        child.add_file(parent.excel.content, 'content', change_file_extension(parent.label, 'csv'))

        # Return the object if it saves successfully and false otherwise 
        child.save! ? child : falses
      end

      def self.word_to_thumbnail(parent) 
        assert_parent_is(parent, MswordFile) 

        desc = "Thumbnail for #{parent.pid}"

        pdf = word_to_pdf(parent) 

        # Generate thumbnail image 
        pdf.transform_datastream :content, { thumb: {size: '100x100>', datastream: 'thumbnail' } }

        child = instantiate_with_metadata(parent, "#{parent.title} thumbnail", desc, ImageThumbnailFile) 
        child.add_file(pdf.thumbnail.content, 'content', thumbnailify(parent.label))

        child.save! ? child : false 
      end

      private

        def self.purge_thumbnail(parent) 
          core = parent.core_record 
          thumb = core.content_objects.find { |c| c.instance_of? ImageThumbnailFile } 
          thumb.destroy unless thumb.nil? 
        end

        def self.purge_pdf(parent) 
          core = parent.core_record 
          pdf = core.content_objects.find { |p| p.instance_of? PdfFile } 
          pdf.destroy unless pdf.nil? 
        end

        def self.purge_csv(parent) 
          core = parent.core_record 
          csv = core.content_objects.find { |p| p.instance_of? TextFile }
          csv.destroy unless csv.nil? 
        end

        def self.image_pdf_to_thumbnail(parent, klass)
          assert_parent_is(parent, klass) 

          desc = "Thumbnail for #{parent.pid}" 

          child = instantiate_with_metadata(parent, "#{parent.title} thumbnail", desc, ImageThumbnailFile) 

          parent.transform_datastream :content, {thumb: { size: '100x100>', datastream: 'thumbnail' } } 
          child.add_file(parent.thumbnail.content, 'content', thumbnailify(parent.label))

          child.save! ? child : false 
        end


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
            raise Exceptions::ParentMismatchError.new(parent, klass)
          end
        end
         
    end
  end
end