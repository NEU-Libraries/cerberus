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
    core_file.depository = "000000000"
    core_file.collection = Collection.find(parent)
    
    core_file.tag_as_in_progress
    # Context derived attributes
    core_file.title = file.original_filename
    core_file.tmp_path = tmp_path
    core_file.original_filename = file.original_filename
    core_file.label = file.original_filename

    core_file.instantiate_appropriate_content_object(tmp_path)

    # If the content_object created is an ImageMasterFile, we want to read the image and store as session vars
    # the length of its longest side.  This is used to calculate the dimensions to allow for the small/med/large
    # sliders on the Provide Metadata page.
    if core_file.canonical_class == "ImageMasterFile"
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

    # Featured Content tagging
    sc_type = collection.smart_collection_type

    if !sc_type.nil? && sc_type != ""
      core_file.category = sc_type
    end

    # Create a handle
    core_file.identifier = make_handle(core_file.persistent_url)
    #core_file.save!
    #return core_file

    # Process Thumbnail
    Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))

    # Add drs staff to permissions for #608
    core_file.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

    if core_file.save!
      if params[:core_file] && !@core_file.category.first.blank?
        UploadAlert.create_from_core_file(core_file, :create)
      end
    end

    #redirect_to core_file_path(@core_file.pid)
  end
end
