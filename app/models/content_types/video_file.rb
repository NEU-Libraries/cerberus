class VideoFile < ActiveFedora::Base 
  include Drs::NuFile
  def type_label
    "Video File"
  end
end