class MsexcelFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "MS Excel File"
  end
end