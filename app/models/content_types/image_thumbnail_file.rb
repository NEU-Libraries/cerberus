class ImageThumbnailFile < ActiveFedora::Base
  include Drs::NuFile

  has_file_datastream name: 'thumbnail_1',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_2',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_3',  type: FileContentDatastream
  has_file_datastream name: 'thumbnail_4',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_5',  type: FileContentDatastream
end
