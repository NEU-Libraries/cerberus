class ResolrizeJob
  def queue_name
    :resolrize
  end

  def run
    require 'fileutils'
    # Disabling as a result of SolrService's poor thread handling
    # which creates #<ThreadError: can't create Thread (11)> errors

    # require 'active_fedora/version'
    # active_fedora_version = Gem::Version.new(ActiveFedora::VERSION)
    # minimum_feature_version = Gem::Version.new('6.4.4')
    # if active_fedora_version >= minimum_feature_version
    #   ActiveFedora::Base.reindex_everything("pid~#{Cerberus::Application.config.id_namespace}:*")
    # else
    #   ActiveFedora::Base.reindex_everything
    # end

    # #{Rails.root}
    # log/solrizer.log

    job_id = "#{Time.now.to_i}-resolrize"

    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/resolrize-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/resolrize-job-failed-pids.log")

    conn = ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials).connection
    rsolr_conn = ActiveFedora::SolrService.instance.conn

    conn.search(nil) do |object|
      begin
        pid = object.pid
        obj = ActiveFedora::Base.find(pid, :cast=>true)
        if obj.is_a?(CoreFile)
          result = obj.healthy?
          if result == true
            rsolr_conn.add(obj.to_solr)
            rsolr_conn.commit
            logger.info "#{Time.now} - Processed PID: #{pid}"
          else
            # we have some errors on validation
            result[:errors].each do |e|
              errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
              errors_for_pid.warn(e)
            end
          end
        end
      rescue Exception => error
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
        # logger.warn "#{Time.now} - #{$!.inspect}"
        # logger.warn "#{Time.now} - #{$!}"
        # logger.warn "#{Time.now} - #{$@}"
      end
    end
  end
end
