class TextFile < ActiveFedora::Base
  include Drs::NuFile
  include Sufia::NuCoreFile::FullTextIndexing

  def type_label
    "txt"
  end
end
