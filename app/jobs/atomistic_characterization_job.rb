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
      elsif c_object.instance_of?(MsWordFile) 
        #TODO Implement me
      end
    end 

    def update_thumbnail_metadata(thumbnail) 
      # Update or instantiate thumbnail attributes 
      thumbnail.title = "#{c_object.title} thumbnail" 
      thumbnail.depositor = c_object.depositor 
      thumbnail.core_record = NuCoreFile.find(c_object.core_record.pid) 
      thumbnail.keywords = c_object.keywords.flatten unless c_object.keywords.nil? 
      thumbnail.description = "Thumbnail for #{c_object.pid}" 
      thumbnail.rightsMetadata.content = c_object.rightsMetadata.content

      thumbnail.save! ? thumbnail : logger.warn("Thumbnail creation failed")  
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