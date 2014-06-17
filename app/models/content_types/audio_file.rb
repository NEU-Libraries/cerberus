class AudioFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "audio"
  end
end
