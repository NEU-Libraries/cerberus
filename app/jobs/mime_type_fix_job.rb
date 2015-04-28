class MimeTypeFixJob
  include ChecksumHelper
  include MimeHelper

  attr_accessor :pid, :job_id

  def initialize(pid, job_id)
    self.pid = pid
    self.job_id = job_id
  end

  def queue_name
    :mime_type_fix
  end

  def run
    require 'fileutils'

    pid = self.pid
    job_id = self.job_id

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/mime-type-fix-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/mime-type-fix-job-failed-pids.log")
    
    begin
      # get fedora object for content file
      cf = ActiveFedora::Base.find(pid, cast:true)
      cf.properties.mime_type = extract_mime_type(cf.fedora_file_path)
      cf.properties.md5_checksum = new_checksum(cf.fedora_file_path)
      cf.save!
      progress_logger.info "#{Time.now} - Processed #{pid}"
    rescue Exception => error
      failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
      errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
      errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
      errors_for_pid.warn "#{Time.now} - #{$!}"
      errors_for_pid.warn "#{Time.now} - #{$@}"
    end

  end
end
