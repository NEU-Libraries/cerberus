class MspowerpointFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "powerpoint"
  end
end
