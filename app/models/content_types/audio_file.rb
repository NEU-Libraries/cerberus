class AudioFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "Audio File"
  end
end