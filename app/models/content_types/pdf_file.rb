class PdfFile < ActiveFedora::Base
  include Drs::NuFile
  include Sufia::NuCoreFile::FullTextIndexing

  def type_label
    "pdf"
  end
end
