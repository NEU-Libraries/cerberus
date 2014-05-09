module Drs
  module NuCoreFile
  # Actions are decoupled from controller logic so that they may be called from a controller or a background job.
    module Actions
      def self.virus_check(file)
        if defined? ClamAV
          stat = ClamAV.instance.scanfile(file.path)
          logger.warn "Virus checking did not pass for #{file.inspect} status = #{stat}" unless stat == 0
          stat
        else
          logger.warn "Virus checking disabled for #{file.inspect}"
          0
        end
      end
    end
  end
end
