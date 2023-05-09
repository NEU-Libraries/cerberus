class ScaledImageJob
  include ApplicationHelper
  attr_accessor :small, :medium, :large, :master_pid, :core_pid

  def initialize(small, medium, large, master_pid, core_pid)
    self.small = small
    self.medium = medium
    self.large = large
    self.master_pid = master_pid
    self.core_pid = core_pid
  end

  def queue_name
    :scaled_image
  end

  def run
    ScaledImageCreator.new(small, medium, large, master_pid).create_scaled_images

    core_record = CoreFile.find(core_pid)
    core_record.tag_as_completed
    core_record.save!
    invalidate_cache("/content_objects/#{core_pid}*")
  end

end
