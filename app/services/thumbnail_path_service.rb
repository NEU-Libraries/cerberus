class ThumbnailPathService
  class << self
    # @param [Work] object - to get the thumbnail for
    # @return [String] a path to the thumbnail
    def call(object)
      fs = object.file_sets.first
      return default_image unless fs
      return default_image unless fs.thumbnail
      return thumbnail_path(fs)
    end

    protected

      def thumbnail_path(fs)
        Rails.application.routes.url_helpers.download_path(fs, file: 'thumbnail')
      end

      def default_image
        # TODO
        ""
      end
  end
end
