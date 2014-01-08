class ZipFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "Zip Archive"
  end
end