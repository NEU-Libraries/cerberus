class ImageSmallFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "small"
  end
end
