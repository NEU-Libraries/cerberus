require 'RMagick'
include Magick

module Cerberus::ThumbnailCreation
  def create_all_thumbnail_sizes(file_path, thumb_pid)
    create_scaled_progressive_jpeg(thumb_pid, file_path, {height: 85, width: 85}, 'thumbnail_1')
    create_scaled_progressive_jpeg(thumb_pid, file_path, {height: 170, width: 170}, 'thumbnail_2')
    create_scaled_progressive_jpeg(thumb_pid, file_path, {height: 340, width: 340}, 'thumbnail_3')
    create_scaled_progressive_jpeg(thumb_pid, file_path, {width: 500}, 'thumbnail_4')
    create_scaled_progressive_jpeg(thumb_pid, file_path, {width: 1000}, 'thumbnail_5')
  end

  private
    def create_scaled_progressive_jpeg(item_pid, file_path, size, dsid)
      # Wrap in rescue block - some pdf's we're supplied with are broken
      # or ghostscript can't handle them
      begin
        item = ActiveFedora::Base.find(item_pid, cast: true)

        if item.core_record.canonical_class.in?(['MswordFile', 'PdfFile'])
          img = Magick::Image.read("#{file_path}[0]").first
        else
          img = Magick::Image.read(file_path).first
        end

        if size[:height] && size[:width]
          scaled_img = img.resize_to_fit(size[:height], size[:width])
          fill = Magick::Image.new(size[:height], size[:width])
          fill = fill.matte_floodfill(1, 1)
          end_img = fill.composite!(scaled_img, Magick::CenterGravity, Magick::OverCompositeOp)

          scaled_img.destroy!
        elsif size[:width]
          end_img = img.resize_to_fit(size[:width])
        else
          raise "Size must be hash containing :height/:width or :width keys"
        end

        end_img.format = "JPEG"
        end_img.interlace = Magick::PlaneInterlace

        item.add_file(end_img.to_blob, dsid, "#{dsid}.jpeg")
        item.save!

        img.destroy!
        end_img.destroy!
      rescue Exception => error
        ExceptionNotifier.notify_exception(error, :data => {:pid => "#{item_pid}"})
      end
    end
end
