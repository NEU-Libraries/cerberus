class MswordFile < ActiveFedora::Base
  include Drs::ContentFile
  include Drs::CoreFile::FullTextIndexing
end
