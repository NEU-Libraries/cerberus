module Drs::InlineThumbnail 
  extend ActiveSupport::Concern 

  included do 
    has_file_datastream "thumbnail", type: FileContentDatastream
  end
end