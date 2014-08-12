class TextFile < ActiveFedora::Base
  include Drs::NuFile
  include Drs::NuCoreFile::FullTextIndexing

  def type_label
    "txt"
  end
end
