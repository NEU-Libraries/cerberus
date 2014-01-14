class TextFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "Text File"
  end
end