class TextFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "txt"
  end
end
