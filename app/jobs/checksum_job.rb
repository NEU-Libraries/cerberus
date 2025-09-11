class ChecksumJob

  attr_accessor :content_pid

  def initialize(content_pid)
    self.content_pid = content_pid
  end

  def queue_name
    :checksum
  end

  def run
    # fetch content object
    content_object = ActiveFedora::Base.find(content_pid, cast: true)

    if File.exists?(co.fedora_file_path)
      # 2 gig limit, or Azure NFS churns
      if (File.size(co.fedora_file_path).to_f / 1024000).round(2) < 2000
        cs = `md5sum #{co.fedora_file_path.shellescape}`.split(" ").first
        content_object.properties.md5_checksum = cs
        content_object.save!
      else
        logger.warn "#{content_object} too large to checksum"
      end
    else
      logger.warn "#{content_object} fedora file path empty"
    end
  end
end
