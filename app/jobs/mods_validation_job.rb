class ModsValidationJob
  attr_accessor :pid, :job_id

  def initialize(pid, job_id)
    self.pid = pid
    self.job_id = job_id
  end

  def queue_name
    :mods_validation
  end

  def run
    pid = self.pid
    job_id = self.job_id

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/mods-validation-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/mods-validation-job-failed-pids.log")

    rsolr_conn = ActiveFedora::SolrService.instance.conn

    begin
      obj = ActiveFedora::Base.find(pid, :cast=>true)

      if obj.is_a?(CoreFile)
        result = obj.healthy?
        if result == true
          progress_logger.info "#{Time.now} - Processed PID: #{pid}"
        else
          # we have some errors on validation
          failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"

          result[:errors].each do |e|
            errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
            errors_for_pid.warn(e)
          end
        end
      end
    rescue Exception => error
      failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
      errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
      errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
      errors_for_pid.warn "#{Time.now} - #{$!}"
      errors_for_pid.warn "#{Time.now} - #{$@}"
    end
  end
end
