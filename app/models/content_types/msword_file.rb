class MswordFile < ActiveFedora::Base
  include Drs::NuFile
  include Sufia::NuCoreFile::FullTextIndexing

  def type_label
    "msword"
  end
end
