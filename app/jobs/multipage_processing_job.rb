include Cerberus::ThumbnailCreation

class MultipageProcessingJob
  attr_accessor :dir_path, :file_values, :core_file

  def queue_name
    :loader_multipage_processing
  end

  def initialize(dir_path, file_values, core_file)
    self.dir_path = dir_path
    self.file_values = file_values
    self.core_file = core_file
  end

  def run
    file_path = self.dir_path + "/" + self.file_values["file_name"]

    # test file_path
    if File.exists?(file_path)

      # Create thumbnail obj
      thumb = PageFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))

      thumb.title                  = self.file_values["title"]
      thumb.identifier             = thumb.pid
      thumb.keywords               = self.core_file.keywords.flatten unless self.core_file.keywords.nil?
      thumb.depositor              = self.core_file.depositor
      thumb.proxy_uploader         = self.core_file.proxy_uploader
      thumb.core_record            = self.core_file
      thumb.rightsMetadata.content = self.core_file.rightsMetadata.content
      thumb.ordinal_value          = self.file_values["sequence"]
      thumb.save!

      create_all_thumbnail_sizes(file_path, thumb.pid)
    else
      # TODO: raise error
    end
  end

end
