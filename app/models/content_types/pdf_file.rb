class PdfFile < ActiveFedora::Base
  include Drs::ContentFile
  include Drs::CoreFile::FullTextIndexing
end
