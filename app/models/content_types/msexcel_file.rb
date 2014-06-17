class MsexcelFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "excel"
  end
end
