class ContentCreationJob

  attr_accessor :core_file_pid, :file_path, :file_name, :delete_file, :poster_path, :small_size, :medium_size, :large_size
  attr_accessor :core_record, :employee

  def queue_name
    :content_creation
  end

  def initialize(core_file, file_path, file_name, poster_path=0, small_size=0, medium_size=0, large_size=0, delete_file=true)
    self.core_file_pid = core_file
    self.file_path     = file_path
    self.file_name     = file_name
    self.delete_file   = delete_file

    self.poster_path = poster_path

    self.small_size    = small_size
    self.medium_size   = medium_size
    self.large_size    = large_size
  end

  def run
    begin
      self.core_record = CoreFile.find(core_file_pid)

      klass = core_record.canonical_class.constantize
      content_object = klass.new(pid: Drs::Noid.namespaceize(Drs::IdService.mint))

      # TODO: re-do video poster creation...
      # if content_object.instance_of? VideoFile
      #   InlineThumbnailCreator.new(content_object, poster_path, "poster").create_thumbnail_and_save
      # end

      # Zip files that need zippin'.  Just drop in other file types.
      if content_object.instance_of? ZipFile
        zip_content(content_object)
      else
        file_contents = File.open(file_path)
        content_object.add_file(file_contents, 'content', file_name)
      end

      # Assign relevant metadata
      content_object.core_record    = core_record
      content_object.title          = file_name
      content_object.identifier     = content_object.pid
      content_object.depositor      = core_record.depositor
      content_object.proxy_uploader = core_record.proxy_uploader
      content_object.rightsMetadata.content = core_record.rightsMetadata.content

      content_object.original_filename = core_record.original_filename

      content_object.canonize
      content_object.characterize

      content_object.save! ? content_object : false

      # If the file is of type with text, see if we can get solr to do a full text index
      if core_record.canonical_class.in?(['TextFile', 'MswordFile', 'PdfFile'])
        content_object.extract_content
      end

      if (content_object.instance_of? ImageMasterFile)
         ScaledImageCreator.new(small_size, medium_size, large_size, content_object).create_scaled_images
      end

      DerivativeCreator.new(content_object.pid).generate_derivatives

      # Derivative creator modifies the core record and these changes are
      # overriden if we save this open copy of the core record without
      # reloading it first
      core_record.reload
      core_record.tag_as_completed
      core_record.save!
      return content_object
    ensure
      if delete_file
        FileUtils.rm(file_path)
      end
    end
  end

  private

    def zip_content(content_object)
      begin
        # Create the name for the zipfile.
        z = File.basename(file_name, ".*") + ".zip"
        zipfile_name = Rails.root.join("tmp", z).to_s

        # Load our content into said zipfile.
        Zip::Archive.open(zipfile_name, Zip::CREATE) do |zipfile|
          zipfile.add_file(file_path)
        end

        # Add zipfile to the ZipFile object
        f = File.open(zipfile_name)
        content_object.add_file(f, "content", File.basename(zipfile_name))
      ensure
        FileUtils.rm(zipfile_name)
      end
    end
end
