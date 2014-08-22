require 'RMagick'
include Magick

module Drs::ThumbnailCreation
  def create_scaled_progressive_jpeg(thumb, blob, thumbnail_list, size, dsid)

    # if (master.is_a? ImageMasterFile) && !(master.width.first.to_i >= size[:width])
    #   return false
    # end

    img = Magick::Image.from_blob(blob).first

    if size[:height] && size[:width]
      scaled_img = img.resize_to_fit(size[:height], size[:width])
      fill = Magick::Image.new(size[:height], size[:width])
      fill = fill.matte_floodfill(1, 1)
      end_img = fill.composite!(scaled_img, Magick::CenterGravity, Magick::OverCompositeOp)
    elsif size[:width]
      end_img = img.resize_to_fit(size[:width])
    else
      raise "Size must be hash containing :height/:width or :width keys"
    end

    end_img.format = "JPEG"
    end_img.interlace = Magick::PlaneInterlace

    thumb.add_file(end_img.to_blob, dsid, "#{self.master.content.label.split('.').first}.jpeg")
    thumb.save!

    thumbnail_list << "/downloads/#{self.core.thumbnail.pid}?datastream_id=#{dsid}"
  end
end
