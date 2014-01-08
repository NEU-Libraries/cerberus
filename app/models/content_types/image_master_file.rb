class ImageMasterFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "Master Image File"
  end
end