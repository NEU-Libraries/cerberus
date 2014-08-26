class PdfFile < ActiveFedora::Base
  include Cerberus::ContentFile
  include Cerberus::CoreFile::FullTextIndexing
end
