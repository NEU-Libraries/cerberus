require 'RMagick'
include Magick

# Responsible for generating inline thumbnails, which are used on
# community and collection objects.  Actual thumbnail creation for
# content objects is handled elsewhere.
class SetThumbnailCreationJob
  attr_accessor :set, :file, :dsid

  # Takes as arguments an ActiveFedora object.
  # An HTTP Uploaded File object or a full string path to a file.
  # And the desired datastream ID
  def initialize(set, file, dsid)
    @set = set
    @file = file
    @dsid = dsid
  end

  def queue_name
    :set_thumbnail_creation
  end

  def run
  end

  def create_thumbnail
    if file.instance_of? String
      process_string
    elsif file.instance_of? ActionDispatch::Http::UploadedFile
      process_uploaded_file
    else
      raise "Invalid type of #{file.class} passed to create_thumbnail." +
            "  Must be string or UploadedFile object."
    end
  end

  def create_thumbnail_and_save
    create_thumbnail
    set.thumbnail_list = ["/downloads/#{self.set.pid}?datastream_id=thumbnail"]
    set.save!
  end

  private

    # Creates a Tempfile with the content at the specified
    # path and modifies it to create a scaled thumbnail.
    # Avoids overwriting fixture data, which will usually be
    # what string paths are pointing at.
    def process_string
      begin
        fname = File.basename(file)

        tmp = Tempfile.new("inline_thumb")
        tmp.write File.open(file).read
        path = tmp.path

        generate_thumbnail(path)

        thumbnail = File.open(tmp, 'rb').read

        set.add_file(thumbnail, dsid, fname)
      ensure
        tmp.unlink
      end
    end

    def process_uploaded_file
      path = file.tempfile.path
      fname = file.original_filename

      generate_thumbnail(path)

      thumbnail = file

      set.add_file(thumbnail, dsid, fname)
    end

    # Modify this if changes in the actual thumbnail dimensions/ppi/whatever
    # are required in the future.
    def generate_thumbnail(path)
      img = Magick::Image.read(path).first
      thumb = img.resize_to_fill(175, 175)
      thumb.write path
    end
end
