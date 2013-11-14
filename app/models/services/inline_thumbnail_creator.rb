require 'RMagick'
include Magick

# Responsible for generating inline thumbnails, which are used on 
# community and collection objects.  Actual thumbnail creation for 
# content objects is handled elsewhere. 
class InlineThumbnailCreator
  attr_accessor :set, :file, :dsid

  # Takes as arguments a collection object
  # An HTTP Uploaded File object or a full string path to a file. 
  # And the desired datastream ID
  def initialize(set, file, dsid)
    @set = set 
    @file = file 
    @dsid = dsid 
  end

  def create_thumbnail
    if file.instance_of? String
      fname = File.basename(file)

      tmp = Tempfile.new("inline_thumb")
      tmp.write File.open(file).read 

      puts "fname is #{fname}" 
      path = tmp.path 
      puts "tmp path is #{path}"
    elsif file.instance_of? ActionDispatch::Http::UploadedFile
      path = file.tempfile.path 
      fname = file.original_filename 
    else 
      raise "Invalid type of #{file.class} passed to create_thumbnail." +
            "  Must be string or UploadedFile object." 
    end

    img = Magick::Image.read(path).first
    thumb = img.resize_to_fill(175, 175) 
    thumb.write path

    if file.instance_of? String 
      data = File.open(tmp).read
    else
      data = file 
    end

    set.add_file(data, dsid, fname)

    tmp.unlink if file.instance_of? String
  end

  def create_thumbnail_and_save
    create_thumbnail
    set.save! 
  end
end