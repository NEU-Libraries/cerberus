class VideoFile < ActiveFedora::Base
  include Cerberus::ContentFile
  has_file_datastream name: 'poster', type: FileContentDatastream
end
