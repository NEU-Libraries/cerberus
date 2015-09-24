class MultipageProcessingJob
  attr_accessor :file, :file_name, :core_file, :copyright, :report_id, :permissions, :client
  include MimeHelper
  include HandleHelper

  def queue_name
    :loader_multipage_processing
  end

  def initialize(file, file_name, core_file, copyright, report_id, permissions=[], client=nil)
    self.file = file
    self.file_name = file_name
    self.core_file = core_file
    self.copyright = copyright
    self.report_id = report_id
    self.permissions = permissions
    self.client = client
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to image_report
    require 'fileutils'
    require 'mini_exiftool'
    MiniExiftool.command = "#{Cerberus::Application.config.minitool_path}"
    job_id = "#{Time.now.to_i}-loader-multipage"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/loader-multipage-process-job.log")
    load_report = Loaders::LoadReport.find(report_id)
    begin

    rescue Exception => error
      # TODO: fill in
    end
  end

end
