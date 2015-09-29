class IndexJob
  attr_accessor :pid, :job_id

  def initialize(pid, job_id)
    self.pid = pid
    self.job_id = job_id
  end

  def queue_name
    :index
  end

  def run
    pid = self.pid
    job_id = self.job_id

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/resolrize-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/resolrize-job-failed-pids.log")

    rsolr_conn = ActiveFedora::SolrService.instance.conn

    begin
      obj = ActiveFedora::Base.find(pid, :cast=>true)

      if ![Community, Collection, Compilation, Employee].include? obj.class

        if obj.datastreams.keys.include? "content"
          # Add file size if it doesn't have it
          if obj.properties.file_size.first.blank?
            obj.properties.file_size = File.size(obj.fedora_file_path).to_s
            obj.save!
          end
        end

        # Delete it's old solr record
        ActiveFedora::SolrService.instance.conn.delete_by_id("#{pid}", params: {'softCommit' => true})

        # Remake the solr document
        rsolr_conn.add(obj.to_solr)
        rsolr_conn.commit

      end

      progress_logger.info "#{Time.now} - Processed PID: #{pid}"

    rescue Exception => error
      failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
      errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
      errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
      errors_for_pid.warn "#{Time.now} - #{$!}"
      errors_for_pid.warn "#{Time.now} - #{$@}"
    end
  end
end
