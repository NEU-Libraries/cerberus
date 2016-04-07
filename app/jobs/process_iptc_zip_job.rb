class ProcessIptcZipJob
  include ZipHelper
  
  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :permissions, :client, :derivatives

  def queue_name
    :iptc_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user, permissions, derivatives=false, client=nil)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.derivatives = derivatives
    self.client = client
  end

  def run
    report_id = Loaders::LoadReport.create_from_strings(current_user, 0, loader_name, parent)
    load_report = Loaders::LoadReport.find(report_id)
    # unzip zip file to tmp storage
    unzip(zip_path, load_report, derivatives, client)
  end

  def unzip(file, load_report, derivatives=false, client)
    dir_path = File.join(File.dirname(file), File.basename(file, ".*"))

    # Extract load zip
    file_list = safe_unzip(file, dir_path)

    count = 0
    # loop through file list
    file_list.each do |fpath|
      file_name = File.basename(fpath)
      ImageProcessingJob.new(fpath, file_name, parent, copyright, load_report.id, permissions, derivatives, client).run
      load_report.update_counts
      count = count + 1
      load_report.save!
    end

    load_report.number_of_files = count
    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
      FileUtils.rmdir(dir_path)
    end
    load_report.save!

    FileUtils.rm(file)
  end
end
