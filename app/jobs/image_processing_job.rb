class ImageProcessingJob
  attr_accessor :file

  def queue_name
    :loader_image_processing
  end

  def initialize(file)
    self.file = file
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to image_report
    photo = IPTC::JPEG::Image.from_file file, quick=true
    photo.values.each do |item|
      puts "#{item.key}\t#{item.value}"
      if item.key == 'iptc/Headline'
        core_file.title = item.value
      # creator (iptc/Credit)
      #elsif item.key == 'iptc/Credit'
      #  core_file.corporate_creators = item.value
      elsif item.key == 'iptc/Caption'
        core_file.description = item.value
      # organization (iptc/Source)
      #elsif item.key == 'iptc/Source'
      #  core_file.organization = item.value
      #elsif item.key == 'iptc/Keywords'
      #  core_file.keywords = item.value
      end
    end
  end
end
