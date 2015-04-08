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

        # Check its MODS and update if needed
        begin
          # Check MODS schemalocation value
          doc = Nokogiri::XML(obj.mods.content)
          schemata_by_ns = Hash[ doc.root.attributes['schemaLocation'].value.scan(/(\S+)\s+(\S+)/) ]
          if schemata_by_ns["http://www.loc.gov/mods/v3"] == "http://www.loc.gov/standards/mods/v3/mods-3-4.xsd"
            # Update to 3-5 as per #703
            doc.root.attributes['schemaLocation'].value = "http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd"
            obj.mods.content = doc.root.to_s
            obj.save!
          end
        rescue NoMethodError
          # If this an obj that doesn't have mods, thats ok, else, log it
          if !self.class.in?([Collection, Community, CoreFile, Compilation])
            failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
            errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
            errors_for_pid.warn "This #{self.class.to_s} has no MODS to inpsect or update"
          end
        rescue Exception
          failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
          errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
          errors_for_pid.warn(e)
        end

        # Delete it's old solr record
        ActiveFedora::SolrService.instance.conn.delete_by_id("#{pid}", params: {'softCommit' => true})        

        # Remake the solr document
        rsolr_conn.add(obj.to_solr)
        rsolr_conn.commit

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
        else
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

    progress_logger.info "#{Time.now} - Done!"
  end
end
