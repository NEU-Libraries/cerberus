class ImageMasterFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "master"
  end
end
