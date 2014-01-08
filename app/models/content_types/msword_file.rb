class MswordFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "MS Word File"
  end
end