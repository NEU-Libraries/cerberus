class VideoFile < ActiveFedora::Base
  include Drs::NuFile
  has_file_datastream name: 'poster', type: FileContentDatastream
  def type_label
    "Video File"
  end
end
