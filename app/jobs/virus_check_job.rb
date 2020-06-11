class VirusCheckJob
  include MimeHelper

  attr_accessor :file_path, :core_file_pid

  def initialize(file_path, core_file_pid)
    self.file_path = file_path
    self.core_file_pid = core_file_pid
  end

  def queue_name
    :virus_check
  end

  def run
    if defined? ClamAV
      output = `clamdscan --fdpass --no-summary --stdout #{file_path}`
      stat = output.split(":", 2)[1].strip
      if !stat.eql?("OK")
        core_file = CoreFile.find(core_file_pid)
        core_file.tombstone("Suspicious binary " + DateTime.now.strftime("%F"))
        logger.warn "Virus checking did not pass for #{core_file_pid} - #{file_path}"
        VirusMailer.virus_alert(core_file_pid)
      end
    else
      logger.warn "Virus checking disabled for #{file_path}"
    end
  end
end
