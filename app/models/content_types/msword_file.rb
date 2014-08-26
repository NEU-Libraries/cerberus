class MswordFile < ActiveFedora::Base
  include Cerberus::ContentFile
  include Cerberus::CoreFile::FullTextIndexing
end
