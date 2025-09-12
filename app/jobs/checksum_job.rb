class ChecksumJob

  attr_accessor :content_pid

  def initialize(content_pid)
    self.content_pid = content_pid
  end

  def queue_name
    :checksum
  end

  def run
    if File.exists?(disk_path)
      # 2 gig limit, or Azure NFS churns
      if (File.size(disk_path).to_f / 1024000).round(2) < 2000
        cs = `md5sum #{disk_path.shellescape}`.split(" ").first

        begin
          retries ||= 0

          # fetch content object
          content_object = ActiveFedora::Base.find(content_pid, cast: true)
          content_object.properties.md5_checksum = cs
          content_object.save!
        rescue Exception => error
          retry if (retries += 1) < 3
        end
      else
        logger.warn "#{content_pid} too large to checksum"
      end
    else
      logger.warn "#{content_pid} fedora file path empty"
    end
  end

  def disk_path
    config_path = Rails.application.config.fedora_home
    datastream_str = "info:fedora/#{content_pid}/content/content.0"
    escaped_datastream = Rack::Utils.escape(datastream_str)
    md5_str = Digest::MD5.hexdigest(datastream_str)
    dir_name = md5_str[0,2]
    file_path = config_path + dir_name + "/" + escaped_datastream
    return file_path
  end
end
