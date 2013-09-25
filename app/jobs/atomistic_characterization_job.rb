class AtomisticCharacterizationJob

  attr_accessor :content_pid

  def queue_name 
    :atomistic_characterize 
  end

  def initialize(pid) 
    self.content_pid = pid 
  end

  def run 
    content_object = ActiveFedora::Base.find(content_pid, cast: true) 

    content_object.characterize
  end
end