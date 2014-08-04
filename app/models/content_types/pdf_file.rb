class PdfFile < ActiveFedora::Base
  include Drs::NuFile
  include Drs::NuCoreFile::FullTextIndexing

  def type_label
    "pdf"
  end
end
