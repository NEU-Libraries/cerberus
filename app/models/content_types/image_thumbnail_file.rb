class ImageThumbnailFile < ActiveFedora::Base
  include Drs::NuFile

  # Rather than create 6 'meaningless' entries in the archive for thumbnails
  # used exclusively by the front-end, we collapse the various sizes of thumbnail
  # we might want into a single object.
  has_file_datastream name: 'thumbnail_1',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_2',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_3',  type: FileContentDatastream
  has_file_datastream name: 'thumbnail_4',     type: FileContentDatastream
  has_file_datastream name: 'thumbnail_5',  type: FileContentDatastream
end
