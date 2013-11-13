require 'RMagick'
include Magick

# Responsible for generating inline thumbnails, which are used on 
# community and collection objects.  Actual thumbnail creation for 
# content objects is handled elsewhere. 
class InlineThumbnailCreator
  attr_accessor :set, :file, :dsid

  # Takes as arguments a collection object
  # An HTTP Uploaded File object 
  # And the desired datastream ID
  def initialize(set, file, dsid)
    @set = set 
    @file = file 
    @dsid = dsid 
  end

  #TODO create method 
  def create_thumbnail
    img = Magick::Image.read(file.tempfile.path).first
    thumb = img.resize_to_fill(175, 175) 
    thumb.write file.tempfile.path
    set.add_file(file, dsid, file.original_filename)
  end
end