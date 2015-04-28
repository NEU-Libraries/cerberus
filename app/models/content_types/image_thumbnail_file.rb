class ImageThumbnailFile < ActiveFedora::Base
  include Cerberus::ContentFile

  has_file_datastream name: 'thumbnail_1',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_2',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_3',  type: FileContentDatastream
  has_file_datastream name: 'thumbnail_4',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_5',  type: FileContentDatastream

  def fedora_file_path
    config_path = Rails.application.config.fedora_home
    datastream_str = "info:fedora/#{self.pid}/thumbnail_1/thumbnail_1.0"
    escaped_datastream = Rack::Utils.escape(datastream_str).gsub("_", "%5F")
    md5_str = Digest::MD5.hexdigest(datastream_str)
    dir_name = md5_str[0,2]
    file_path = config_path + dir_name + "/" + escaped_datastream
    return file_path
  end
end
