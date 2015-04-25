class ModsUpdateJob
  attr_accessor :pid, :job_id

  def initialize(pid, job_id)
    self.pid = pid
    self.job_id = job_id
  end

  def queue_name
    :mods_update
  end

  def run
    pid = self.pid
    job_id = self.job_id

    progress_logger = Logger.new("#{Rails.root}/log/#{job_id}/mods-update-job.log")
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/mods-update-job-failed-pids.log")

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
        progress_logger.info "#{Time.now} - Processed PID: #{pid}"
      end
    rescue NoMethodError
      # If this an obj that doesn't have mods, thats ok, else, log it
      if obj.class.in?([Collection, Community, CoreFile, Compilation])
        failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
        errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
        errors_for_pid.warn "This #{obj.class.to_s} has no MODS to inpsect or update"
      end
    end
  end
end
