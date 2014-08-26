class VideoFile < ActiveFedora::Base
  include Drs::ContentFile
  has_file_datastream name: 'poster', type: FileContentDatastream
end
