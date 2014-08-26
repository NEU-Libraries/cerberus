class PdfFile < ActiveFedora::Base
  include Drs::NuFile
  include Drs::CoreFile::FullTextIndexing
end
