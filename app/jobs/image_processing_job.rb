class ImageProcessingJob
  attr_accessor :file, :parent

  def queue_name
    :loader_image_processing
  end

  def initialize(file, parent)
    self.file = file
    self.parent = parent
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to image_report
    core_file = ::CoreFile.new
    core_file.depositor = "000000000"
    core_file.parent = Collection.find(parent)
    core_file.properties.parent_id = core_file.parent.pid
    core_file.tag_as_in_progress
    # Context derived attributes
    core_file.tmp_path = file
    core_file.properties.original_filename = File.basename(file)
    core_file.label = File.basename(file)

    core_file.instantiate_appropriate_content_object(file)
    if core_file.canonical_class == "ImageMasterFile"
      core_file.mods.genre = "photographs"
      core_file.mods.genre.authority = "aat"
      # core_file.mods.digitalOrigin = "born digital"
      # core_file.mods.extent = "1 photograph"
      photo = IPTC::JPEG::Image.from_file file, quick=true
      photo.values.each do |item|
        puts "#{item.key}\t#{item.value}"
        if item.key == 'iptc/Headline'
          core_file.title = item.value
        # creator (iptc/Credit)
        #elsif item.key == 'iptc/Credit'
        #  core_file.corporate_creators = item.value
        elsif item.key == 'iptc/City'
          core_file.mods.origin_info.place.term = item.value
        elsif item.key == 'iptc/Caption'
          core_file.description = item.value
        elsif item.key == 'iptc/Source'
          core_file.mods.origin_info.publisher = item.value
        elsif item.key == "iptc/DateCreated"
          core_file.mods.origin_info.copyright = "#{item.value[0..3]}-#{item.value[4..5]}-#{item.value[6..7]}"
        #elsif item.key == 'iptc/Keywords'
        #  core_file.keywords = item.value
        end
      end
    end

    # Featured Content tagging
    sc_type = core_file.parent.smart_collection_type

    if !sc_type.nil? && sc_type != ""
      core_file.category = sc_type
    end

    # Create a handle
    core_file.identifier = make_handle(core_file.persistent_url)
    #core_file.save!
    #return core_file
    puts core_file.pid
    puts core_file.tmp_path
    puts core_file.original_filename

    # Process Thumbnail
    Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))

    # Add drs staff to permissions for #608
    core_file.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

    if core_file.save!
      if core_file && !core_file.category.first.blank?
        UploadAlert.create_from_core_file(core_file, :create)
      end
    end

    #redirect_to core_file_path(@core_file.pid)
  end
end
