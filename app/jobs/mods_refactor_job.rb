class ModsRefactorJob
  def queue_name
    :mods_refactor
  end

  def run
    require 'fileutils'
    job_id = "#{Time.now.to_i}-mods-refactor"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/mods-refactor-job-failed-pids.log")

    conn = ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials).connection

    conn.search(nil) { |object|
      begin
        pid = object.pid
        # Cerberus::Application::Queue.push(ModsValidationJob.new(pid, job_id))
        Cerberus::Application::Queue.push(ModsUpdateJob.new(pid, job_id))
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
        errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
        errors_for_pid.warn "#{Time.now} - #{$!}"
        errors_for_pid.warn "#{Time.now} - #{$@}"
      end
    }
  end
end
