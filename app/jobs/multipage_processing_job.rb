include Cerberus::ThumbnailCreation
include HandleHelper

class MultipageProcessingJob
  attr_accessor :dir_path, :file_values, :core_file_pid, :report_id, :client, :zip_files

  def queue_name
    :loader_multipage_processing
  end

  def initialize(dir_path, file_values, core_file_pid, report_id, zip_files=nil, client=nil)
    self.dir_path = dir_path
    self.file_values = file_values
    self.core_file_pid = core_file_pid
    self.report_id = report_id
    self.zip_files = zip_files
    self.client = client
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

      if !self.zip_files.blank? && self.zip_files.length == 1
        # just make the one file canonical and add
        co_pid = Cerberus::Noid.namespaceize(Cerberus::IdService.mint)
        content_object = ImageMasterFile.new(pid: co_pid)
        content_object.canonize
        content_object.rightsMetadata.content = core_file.rightsMetadata.content
        content_object.depositor              = core_file.depositor
        content_object.core_record            = core_file
        content_object.save!

        full_path = self.dir_path + "/" + self.zip_files.first

        File.open(full_path) do |file_contents|
          content_object.add_file(file_contents, 'content', self.zip_files.first)
          content_object.save!
        end

        DerivativeCreator.new(co_pid).generate_derivatives

        core_file.reload
        core_file.tag_as_completed
        core_file.canonical_class = "ImageMasterFile"
        core_file.save!
      else

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

      end
    else
      load_report.item_reports.create_failure("File not found in zip file", "", self.file_values["file_name"])
      core_file.destroy
      return
    end

    if self.file_values["sequence"] == "1" && !thumb.blank?
      # Make thumbnails for core_file
      thumbnail_list = []
      for i in 1..5 do
        thumbnail_list << "/downloads/#{thumb.pid}?datastream_id=thumbnail_#{i}"
      end

      core_file.thumbnail_list = thumbnail_list
      if core_file.save!
        UploadAlert.create_from_core_file(core_file, :create, "multipage")
      end
    end

    if !self.zip_files.blank?
      # and if it's not just one file
      if self.zip_files.length > 1
        Cerberus::Application::Queue.push(MultipageCreateZipJob.new(self.dir_path, core_file.pid, self.zip_files))
        core_file.canonical_class = "ZipFile"
        core_file.save!
      end
    end

    if self.file_values["last_item"].downcase == "true"
      load_report.item_reports.create_success(core_file, "")

      core_file.reload
      core_file.identifier = make_handle(core_file.persistent_url, client)
      core_file.save!
    end
  end

end
