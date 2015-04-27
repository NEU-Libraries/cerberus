module ChecksumHelper

  def new_checksum(file_location)
    `md5sum #{file_location}`.split(" ").first
  end

end
