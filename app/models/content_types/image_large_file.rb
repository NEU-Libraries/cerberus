class ImageLargeFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "Large Image File"
  end
end