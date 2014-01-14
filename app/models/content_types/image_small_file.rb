class ImageSmallFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "Small Image File"
  end
end