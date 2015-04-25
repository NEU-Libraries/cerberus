class RecharacterizeJob
  def queue_name
    :recharacterize
  end

  def run
    require 'fileutils'

    job_id = "#{Time.now.to_i}-recharacterize"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/recharacterize-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/recharacterize-job-failed-pids.log")

    # logger = Logger.new("#{Rails.root}/log/recharacterize.log")

    core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
    query_string = "has_model_ssim:\"#{core_file_model}\""
    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

    progress_logger.info "#{Time.now} - Starting recharacterization for canonical objects."

    query_result.each_with_index do |search_result, i|
      pid = query_result[i]["id"]
      begin
        record = ActiveFedora::Base.find(pid, :cast=>true)
        canon = record.canonical_object

        if canon == false
          # All CoreFiles should have a canonical object
          # Most likely a poorly formed object from IRis migration
          failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
          errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
          errors_for_pid.warn "#{Time.now} - This core file has no canonical object"
        else
          # recharacterize
          Cerberus::Application::Queue.push(AtomisticCharacterizationJob.new(canon.pid))
          progress_logger.info "Recharacterizing #{canon.pid}"
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
end
