include Cerberus::ThumbnailCreation

class MultipageProcessingJob
  attr_accessor :dir_path, :file_values, :core_file_pid, :report_id, :zip_files

  def queue_name
    :loader_multipage_processing
  end

  def initialize(dir_path, file_values, core_file_pid, report_id, zip_files = nil)
    self.dir_path = dir_path
    self.file_values = file_values
    self.core_file_pid = core_file_pid
    self.report_id = report_id
    self.zip_files = zip_files
  end

  def run
    core_file = CoreFile.find(self.core_file_pid) || nil

    if core_file.blank?
      return
    end

    load_report = Loaders::LoadReport.find(report_id)
    file_path = self.dir_path + "/" + self.file_values["file_name"]

    # test file_path
    if File.exists?(file_path)

      # Create thumbnail obj
      thumb = PageFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))

      thumb.title                  = self.file_values["title"]
      thumb.identifier             = thumb.pid
      thumb.keywords               = core_file.keywords.flatten unless core_file.keywords.nil?
      thumb.depositor              = core_file.depositor
      thumb.core_record            = core_file
      thumb.rightsMetadata.content = core_file.rightsMetadata.content
      thumb.ordinal_value          = self.file_values["sequence"]
      thumb.ordinal_last           = self.file_values["last_item"] unless self.file_values["last_item"].nil?
      thumb.save!

      create_all_thumbnail_sizes(file_path, thumb.pid)
    else
      load_report.image_reports.create_failure("File not found in zip file", "", self.file_values["file_name"])
      core_file.destroy
      return
    end

    if self.file_values["sequence"] == "1"
      # Make thumbnails for core_file
      thumbnail_list = []
      for i in 1..5 do
        thumbnail_list << "/downloads/#{thumb.pid}?datastream_id=thumbnail_#{i}"
      end

      core_file.thumbnail_list = thumbnail_list
      core_file.save!
    end

    if !self.zip_files.blank?
      Cerberus::Application::Queue.push(MultipageCreateZipJob.new(self.dir_path, core_file.pid, self.zip_files))
    end

    if self.file_values["last_item"].downcase == "true"
      load_report.image_reports.create_success(core_file, "")
    end
  end

end
