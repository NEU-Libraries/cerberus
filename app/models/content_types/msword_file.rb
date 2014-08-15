class MswordFile < ActiveFedora::Base
  include Drs::NuFile
  include Drs::NuCoreFile::FullTextIndexing
end
