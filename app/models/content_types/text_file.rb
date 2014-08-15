class TextFile < ActiveFedora::Base
  include Drs::NuFile
  include Drs::NuCoreFile::FullTextIndexing
end
