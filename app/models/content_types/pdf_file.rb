class PdfFile < ActiveFedora::Base
  include Drs::NuFile
  def type_label
    "pdf"
  end
end
