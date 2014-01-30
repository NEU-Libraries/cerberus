class PdfFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "PDF File"
  end
end