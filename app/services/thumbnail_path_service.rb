class ThumbnailPathService
  class << self
    # @param [Work, FileSet] object - to get the thumbnail for
    # @return [String] a path to the thumbnail
    def call(object)
      # TODO
    end

    protected

      def fetch_thumbnail(object)
        # TODO
      end

      # @return the network path to the thumbnail
      # @param [FileSet] thumbnail the object that is the thumbnail
      def thumbnail_path(thumbnail)
        # TODO
      end

      def default_image
        # TODO
      end

      def audio_image
        # TODO
      end

      # @return true if there a file on disk for this object, otherwise false
      # @param [FileSet] thumb - the object that is the thumbnail
      def thumbnail?(thumb)
        File.exist?(thumbnail_filepath(thumb))
      end

      # @param [FileSet] thumb - the object that is the thumbnail
      def thumbnail_filepath(thumb)
        # TODO
      end
  end
end
