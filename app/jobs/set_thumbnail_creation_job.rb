include Drs::ThumbnailCreation

# Responsible for generating inline thumbnails, which are used on
# community and collection objects.  Actual thumbnail creation for
# content objects is handled elsewhere.
class SetThumbnailCreationJob
  attr_accessor :set_pid, :file_path

  # Takes as arguments an ActiveFedora object.
  # An HTTP Uploaded File object or a full string path to a file.
  # And the desired datastream ID
  def initialize(set_pid, file_path)
    @set_pid = set_pid
    @file_path = file_path
  end

  def queue_name
    :set_thumbnail_creation
  end

  def run
    set = ActiveFedora::Base.find(@set_pid, cast: true)
    blob = File.open(@file_path).read

    create_scaled_progressive_jpeg(set, blob, {height: 85, width: 85}, 'thumbnail_1')
    create_scaled_progressive_jpeg(set, blob, {height: 170, width: 170}, 'thumbnail_2')
    create_scaled_progressive_jpeg(set, blob, {height: 340, width: 340}, 'thumbnail_3')

    for i in 1..3 do
      set.thumbnail_list << "/downloads/#{set_pid}?datastream_id=thumbnail_#{i}"
    end

    set.reload
    set.save!
  end

end
