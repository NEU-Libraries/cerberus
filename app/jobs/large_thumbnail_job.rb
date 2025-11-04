class LargeThumbnailJob

  attr_accessor :content_pid

  def initialize(content_pid)
    self.content_pid = content_pid
  end

  def queue_name
    :large_thumbnail
  end

  def run
    DerivativeCreator.new(content_pid).generate_derivatives
  end
end
