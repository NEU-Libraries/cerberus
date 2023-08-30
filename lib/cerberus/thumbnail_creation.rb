require 'RMagick'
include Magick

module Cerberus::ThumbnailCreation
  def create_all_thumbnail_sizes(file_path, thumb_pid)
    canonical_class = ActiveFedora::Base.find(thumb_pid, cast: true).core_record.canonical_class
    create_scaled_progressive_jpeg(thumb_pid, file_path, {height: 85, width: 85}, 'thumbnail_1', canonical_class)
    create_scaled_progressive_jpeg(thumb_pid, file_path, {height: 170, width: 170}, 'thumbnail_2', canonical_class)
    create_scaled_progressive_jpeg(thumb_pid, file_path, {height: 340, width: 340}, 'thumbnail_3', canonical_class)
    create_scaled_progressive_jpeg(thumb_pid, file_path, {width: 500}, 'thumbnail_4', canonical_class)
    create_scaled_progressive_jpeg(thumb_pid, file_path, {width: 1000}, 'thumbnail_5', canonical_class)
  end

  private
    def create_scaled_progressive_jpeg(item_pid, file_path, size, dsid, canonical_class=nil)
      # Wrap in rescue block - some pdf's we're supplied with are broken
      # or ghostscript can't handle them
      begin
        # item = ActiveFedora::Base.find(item_pid, cast: true)

        if canonical_class.in?(['MswordFile', 'PdfFile'])
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

        extension = ""

        if canonical_class.in?(['MswordFile', 'PdfFile', 'EpubFile'])
          end_img.format = "PNG"
          extension = "png"
        else
          end_img.format = "JPEG"
          end_img.interlace = Magick::PlaneInterlace
          extension = "jpeg"
        end

        # item.add_file(end_img.to_blob, dsid, "#{dsid}.#{extension}")
        # item.save!

        file_name = Time.now.to_f.to_s.gsub!('.','-') + "-thumb.#{extension}"
        tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
        file_path = tempdir.join(file_name).to_s

        # write img to tmp dir
        end_img.write(file_path)

        large_upload(item_pid, file_path, dsid)

        img.destroy!
        end_img.destroy!
      rescue Exception => error
        ExceptionNotifier.notify_exception(error, :data => {:pid => "#{item_pid}"})
      end
    end

    def large_upload(pid, file_path, dsid)
      res = ''
      uri = URI("#{ActiveFedora.config.credentials[:url]}/objects/#{pid}/datastreams/#{dsid}?controlGroup=M&dsLocation=file://#{file_path}")
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.read_timeout = 60000
        request = Net::HTTP::Post.new uri
        request.basic_auth("#{ActiveFedora.config.credentials[:user]}", "#{ActiveFedora.config.credentials[:password]}")
        res = http.request request # Net::HTTPResponse object
      end
      return res
    end
end
