class MswordFile < ActiveFedora::Base
  include Drs::NuFile
  include Drs::NuCoreFile::FullTextIndexing

  def type_label
    "msword"
  end
end
