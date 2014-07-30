class ZipFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "zip"
  end
end
