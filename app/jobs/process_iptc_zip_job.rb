class ProcessIptcZipJob
  include ZipHelper

  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :client, :derivatives, :report_id

  def queue_name
    :iptc_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user, report_id, derivatives=false, client=nil)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.derivatives = derivatives
    self.client = client
    self.report_id = report_id
  end

  def run
    load_report = Loaders::LoadReport.find(report_id)
    # unzip zip file to tmp storage
    unzip(zip_path, load_report, derivatives, client)
  end

  def unzip(file, load_report, derivatives=false, client)
    dir_path = File.join(File.dirname(file), File.basename(file, ".*"))

    # Extract load zip
    total_list = safe_unzip(file, dir_path, true)
    file_list = total_list[0]
    original_names = total_list[1]

    count = 0
    # loop through file list
    file_list.each_with_index do |fpath, i|
      # file_name = File.basename(fpath)
      if (loader_name == "Ocean Genome Legacy")
        ImageProcessingJob.new(fpath, original_names[i], parent, copyright, load_report.id, current_user, derivatives, client, I18n.t('loaders.ogl.note')).run
      else
        ImageProcessingJob.new(fpath, original_names[i], parent, copyright, load_report.id, current_user, derivatives, client).run
      end
      load_report.update_counts
      count = count + 1
      load_report.save!
    end

    load_report.number_of_files = count
    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      load_report.completed = true
      load_report.save!
      LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
      FileUtils.rmdir(dir_path)
    end
    load_report.save!

    # FileUtils.rm(file) # Don't delete marcom ingest zips for safety - sweep will get them
    FileUtils.mv(file, File.dirname(file) + "/#{report_id}.zip") # mv and tag with report id to resume upon issue, by hand
  end
end
