class PropagateCoreMetadataChangeJob
  attr_accessor :core

  def initialize(pid)
    self.core = pid
  end

  def run
    core_record = NuCoreFile.find(core)
    core_record.propagate_metadata_changes!
  end
end
