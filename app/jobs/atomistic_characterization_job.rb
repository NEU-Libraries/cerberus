class AtomisticCharacterizationJob

  attr_accessor :content_pid, :c_object

  def queue_name 
    :atomistic_characterize 
  end

  def initialize(pid) 
    self.content_pid = pid 
  end

  def run
    self.c_object = ActiveFedora::Base.find(content_pid, cast: true)

    c_object.characterize

    if is_master?
      thumb = fetch_thumbnail || ImageThumbnailFile.new 
      update_thumbnail(thumb)
    end
  end

  private

    def update_thumbnail(target)
      if c_object.instance_of?(ImageMasterFile) || c_object.instance_of?(PdfFile)

        # Create a thumbnail stream but don't save it 
        c_object.transform_datastream :content, { thumb: { size: '100x100>', datastream: 'thumbnail' } }

        # Assign it to the content datastream in the thumbnail 
        target.add_file(c_object.thumbnail.content, 'content', labelize('png'))

        update_thumbnail_metadata(target)
      elsif c_object.instance_of?(MswordFile) 
        c_object.transform_datastream :content, { to_pdf: { format: 'pdf', datastream: 'pdf'} }, processor: 'document'
        
        # Generate the PDF file, hop one 
        pdf = create_pdf_file(c_object.pdf.content)

        pdf.transform_datastream :content, { thumb: { size: '100x100>', datastream: 'thumbnail' } } 

        target.add_file(pdf.thumbnail.content, 'content', labelize('png')) 
        update_thumbnail_metadata(target)
      end
    end 

    def create_pdf_file(pdf_content)
      keywords = c_object.keywords.flatten unless c_object.keywords.nil?
      p = PdfFile.new(title: "#{c_object.title} PDF",
                         core_record: NuCoreFile.find(c_object.core_record.pid),
                         depositor: c_object.depositor,
                         keywords: keywords,
                         description: c_object.description, 
                        )
      p.rightsMetadata.content = c_object.rightsMetadata.content
      p.add_file(pdf_content, 'content', title_to_pdf) 
      p.save! ? p : logger.warn("PDF generation failed")   
    end

    def update_thumbnail_metadata(thumbnail) 
      # Update or instantiate thumbnail attributes 
      thumbnail.title = "#{c_object.title} thumbnail" 
      thumbnail.depositor = c_object.depositor 
      thumbnail.core_record = NuCoreFile.find(c_object.core_record.pid) 
      thumbnail.keywords = c_object.keywords.flatten unless c_object.keywords.nil? 
      thumbnail.description = "Thumbnail for #{c_object.pid}" 
      thumbnail.rightsMetadata.content = c_object.rightsMetadata.content

      thumbnail.save! ? thumbnail : Rails.logger.warn("Thumbnail creation failed")  
    end 

    def title_to_pdf 
      a = c_object.label.split(".") 
      a[-1] = 'pdf' 
      return a.join(".") 
    end

    def labelize(file_extension) 
      a = c_object.label.split(".") 
      a[0] = "#{a[0]}_thumb" 
      a[-1] = file_extension
      return a.join(".")
    end
   
    def is_master?
      return c_object.canonical?
    end

    def fetch_thumbnail 
      c_object.core_record.content_objects.find { |e| e.instance_of? ImageThumbnailFile } 
    end
end