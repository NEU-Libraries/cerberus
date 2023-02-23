class IndexJob
  include ApplicationHelper

  attr_accessor :pid_list

  def initialize(pid_list)
    self.pid_list = pid_list
  end

  def queue_name
    :reindex
  end

  def run
    pid_list = self.pid_list
    job_id = "#{Time.now.to_i}"

    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/resolrize-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/resolrize-job-failed-pids.log")

    rsolr_conn = ActiveFedora::SolrService.instance.conn

    begin
      pid_list.each do |pid|
        obj = ActiveFedora::Base.find(pid, :cast=>true)

        # Invalidate cache
        invalidate_pid(pid)

        # Delete it's old solr record
        ActiveFedora::SolrService.instance.conn.delete_by_id("#{pid}", params: {'softCommit' => true})

        # Remake the solr document
        rsolr_conn.add(obj.to_solr)
        rsolr_conn.commit

        progress_logger.info "#{Time.now} - Processed PID: #{pid}"
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
