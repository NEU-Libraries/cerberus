class AtomisticCharacterizationJob

  attr_accessor :content_pid

  def queue_name 
    :atomistic_characterize 
  end

  def initialize(pid) 
    self.content_pid = pid 
  end

  # no_content.add_file(has_content.content.content, "content", "whatever.jpeg")

  def run
    content_object = ActiveFedora::Base.find(content_pid, cast: true)

    content_object.characterize

    puts "Running"
    if is_master?(content_object)
      puts "Item is certainly master" 
      thumb = fetch_thumbnail(content_object) || generate_fresh_thumbnail(content_object)
      update_thumbnail(thumb, content_object)
    end
  end

  # private

    def update_thumbnail(target, c_obj)
      if c_obj.instance_of?(ImageMasterFile) || c_obj.instance_of?(PdfFile)
        puts "Calling transform"
        c_obj.transform_datastream :content, { thumb: { size: '100x100>', datastream: 'thumbnail' } }
        c_obj.save!
      else
        raise "Haven't gotten around to implementing default thumbs"
      end
    end

    def generate_fresh_thumbnail(c_obj)
      core = NuCoreFile.find(c_obj.core_record.pid)

      return ImageThumbnailFile.create(depositor: c_obj.depositor,
                                       core_record: core
                                       )
    end

    # Check if the object is the first uploaded in the most naive 
    # way possible.  Will need to discuss business logic with 
    # Pat next meeting.  
    def is_master?(c_obj)
      return c_obj.instance_of?(ImageMasterFile) || c_obj.instance_of?(PdfFile) 
    end

    def has_thumbnail?(c_obj)
      c_obj.core_record.content_objects.any? { |e| e.instance_of? ImageThumbnailFile } 
    end

    def fetch_thumbnail(c_obj) 
      c_obj.core_record.content_objects.find { |e| e.instance_of? ImageThumbnailFile } 
    end
end