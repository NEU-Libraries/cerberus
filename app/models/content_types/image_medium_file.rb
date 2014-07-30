class ImageMediumFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "medium"
  end
end
