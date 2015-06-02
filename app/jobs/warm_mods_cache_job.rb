class WarmModsCacheJob
  attr_accessor :pid_list

  def initialize(pid_list)
    self.pid_list = pid_list
  end

  def queue_name
    :warm_mods_cache
  end

  def run
    pid_list = self.pid_list

    pid_list.each do |pid|
      begin
        cf = CoreFile.find(pid)
        cf.to_hash
      rescue Exception => error
        #
      end
    end
  end
end
