class ImageLargeFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "large"
  end
end
