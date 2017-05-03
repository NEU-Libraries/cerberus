class ThumbnailPathService
  class << self
    # @param [Work] object - to get the thumbnail for
    # @return [String] a path to the thumbnail
    def call(object, fedora=false)
      fs = object.file_sets.first
      return default_image unless fs
      return default_image unless fs.thumbnail

      if !fedora
        return thumbnail_path(fs)
      else
        return fs.id.scan(/.{2}/).first(4).join("/") + "/" + fs.thumbnail.id
      end
    end

    # def fedora_path(object)
    #   fs = object.file_sets.first
    #   return nil unless fs
    #   return nil unless fs.thumbnail
    #   path = fs.id.scan(/.{2}/).first(4).join("/") + "/" + fs.thumbnail.id
    # end

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
