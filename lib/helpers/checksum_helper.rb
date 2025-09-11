module ChecksumHelper

  def new_checksum(content_object_pid)
    # `md5sum #{file_location.shellescape}`.split(" ").first

    # Fire off a backgrounded checksum
    Cerberus::Application::Queue.push(ChecksumJob.new(content_object_pid))
  end

end
