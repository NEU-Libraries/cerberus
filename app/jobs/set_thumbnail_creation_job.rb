include Drs::ThumbnailCreation

# Responsible for generating inline thumbnails, which are used on
# community and collection objects.  Actual thumbnail creation for
# content objects is handled elsewhere.
class SetThumbnailCreationJob
  attr_accessor :set, :file_path

  # Takes as arguments an ActiveFedora object.
  # An HTTP Uploaded File object or a full string path to a file.
  # And the desired datastream ID
  def initialize(set, file_path)
    @set = set
    @file_path = file_path
  end

  def queue_name
    :set_thumbnail_creation
  end

  def run
    blob = File.open(@file_path)

    if !(file.instance_of? (StringIO)) && !(file.instance_of? ActionDispatch::Http::UploadedFile)
      raise "Invalid type of #{file.class} passed to create_thumbnail." +
            "  Must be string or UploadedFile object."
    end

    create_scaled_progressive_jpeg(@set, blob, @set.thumbnail_list, {height: 85, width: 85}, 'thumbnail_1')
    create_scaled_progressive_jpeg(@set, blob, @set.thumbnail_list, {height: 170, width: 170}, 'thumbnail_2')
    create_scaled_progressive_jpeg(@set, blob, @set.thumbnail_list, {height: 340, width: 340}, 'thumbnail_3')
  end

end
