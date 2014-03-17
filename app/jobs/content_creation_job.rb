class ContentCreationJob

  attr_accessor :core_file_pid, :file_path, :file_name, :user_id, :delete_file
  attr_accessor :core_record, :user

  def queue_name
    :content_creation
  end

  def initialize(core_file, file_path, file_name, user_id, delete_file=true)
    self.core_file_pid = core_file
    self.file_path     = file_path
    self.file_name     = file_name
    self.user_id       = user_id
    self.delete_file   = delete_file
  end

  def run
    begin
      self.user = User.find(user_id)
      self.core_record = NuCoreFile.find(core_file_pid)

      pid = Sufia::Noid.namespaceize(Sufia::IdService.mint)

      #content_object = instantiate_appropriate_content_object(file_path, file_name)
      content_object = core_record.canonical_class.constantize.new(pid)

      assign_dcmi_type(content_object)

      # Zip files that need zippin'.  Just drop in other file types.
      if content_object.instance_of? ZipFile
        zip_content(content_object)
      else
        file_contents = File.open(file_path)
        content_object.add_file(file_contents, 'content', file_name)
      end

      # Assign relevant metadata
      content_object.core_record =  core_record
      content_object.title       =  file_name
      content_object.identifier  =  content_object.pid
      content_object.depositor   =  user.nuid
      content_object.rightsMetadata.content = core_record.rightsMetadata.content

      content_object.canonize

      content_object.save! ? content_object : false
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
