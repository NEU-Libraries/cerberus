class TextFile < ActiveFedora::Base
  include Cerberus::ContentFile
  include Cerberus::CoreFile::FullTextIndexing
end
