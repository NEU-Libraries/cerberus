class PropagateCoreMetadataChangeJob
  attr_accessor :core

  def queue_name
    :propagate_change
  end

  def initialize(pid)
    self.core = pid
  end

  def run
    core_record = CoreFile.find(core)
    core_record.propagate_metadata_changes!
  end
end
