class ImageMediumFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "Medium Image File"
  end
end