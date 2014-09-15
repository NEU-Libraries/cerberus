require 'RMagick'
include Magick

module Cerberus::ThumbnailCreation
  def create_scaled_progressive_jpeg(item_pid, blob, size, dsid)

    # if (master.is_a? ImageMasterFile) && !(master.width.first.to_i >= size[:width])
    #   return false
    # end

    item = ActiveFedora::Base.find(item_pid, cast: true)

    if blob.instance_of? (StringIO)
      blob = blob.string
    end

    begin
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

      item.add_file(end_img.to_blob, dsid, "#{dsid}.jpeg")
      item.save!
    rescue Magick::ImageMagickError => exception
      logger.warn "Unable to make thumbnail with #{item_pid}: #{exception.inspect}"
    end
  end
end
