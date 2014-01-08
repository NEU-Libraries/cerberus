class MspowerpointFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "MS PowerPoint File"
  end
end