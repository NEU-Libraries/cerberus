class AtomisticCharacterizationJob

  attr_accessor :content_pid, :c_object

  def queue_name 
    :atomistic_characterize 
  end

  def initialize(pid) 
    self.content_pid = pid 
  end

  # no_content.add_file(has_content.content.content, "content", "whatever.jpeg")

  def run
    self.c_object = ActiveFedora::Base.find(content_pid, cast: true)

    c_object.characterize

    puts "Running"
    if is_master?
      thumb = fetch_thumbnail || generate_fresh_thumbnail
      update_thumbnail(thumb)
    end
  end

  # private

    def update_thumbnail(target)
      if c_object.instance_of?(ImageMasterFile) || c_object.instance_of?(PdfFile)

        # Create a thumbnail stream but don't save it 
        c_object.transform_datastream :content, { thumb: { size: '100x100>', datastream: 'thumbnail' } }

        # Assign it to the content datastream in the thumbnail 
        target.add_file(c_object.thumbnail.content, 'content', thumb_title)
        target.save!
      else
        raise "Haven't gotten around to implementing default thumbs"
      end
    end

    def generate_fresh_thumbnail
      core = NuCoreFile.find(c_object.core_record.pid)

      i = ImageThumbnailFile.new
      i.title = thumb_title 
      i.depositor = c_object.depositor 
      i.core_record = core 
      i.keywords = c_object.keywords.flatten
      i.description = "Thumbnail for #{c_object.pid}" 


      # Copy permissions of the main object to its thumb.
      i.rightsMetadata.content = c_object.rightsMetadata.content 
      i.save! ? i : logger.warn("Thumbnail creation failed.")  
    end

    def thumb_title
      a = c_object.title.split(".")

      a[0] = "#{a[0]}_thumb" 
      return a.join(".") 
    end

    # Check if the object is the first uploaded in the most naive 
    # way possible.  Will need to discuss business logic with 
    # Pat next meeting.  
    def is_master?
      return c_object.instance_of?(ImageMasterFile) || c_object.instance_of?(PdfFile) 
    end

    def has_thumbnail?
      c_object.core_record.content_objects.any? { |e| e.instance_of? ImageThumbnailFile } 
    end

    def fetch_thumbnail 
      c_object.core_record.content_objects.find { |e| e.instance_of? ImageThumbnailFile } 
    end
end