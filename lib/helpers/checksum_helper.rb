module ChecksumHelper

  def new_checksum(file_location)
    `md5sum #{file_location.shellescape}`.split(" ").first
  end

end
