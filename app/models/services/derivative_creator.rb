require 'RMagick'
include Magick

class DerivativeCreator

  attr_accessor :core, :master

  def initialize(master_pid)
    @master = ActiveFedora::Base.find(master_pid, cast: true)
    @core = NuCoreFile.find(@master.core_record.pid)
    @thumbnail_list = Array.new
  end

  def generate_derivatives

    blob = nil

    if master.instance_of? MswordFile
      pdf = create_pdf_file
      pdf.transform_datastream(:content, content: { datastream: 'content', size: '1000x1000>' })
      blob = pdf.content.content
    else
      blob = self.master.content.content
    end

    if self.master.content.content.instance_of? (StringIO)
      blob = blob.string
    end

    create_all_thumbnail_sizes(blob, @core.thumbnail_list)

    @core.reload
    @core.save!
  end

  private

    def create_all_thumbnail_sizes(blob, thumbnail_list)
      thumb = find_or_create_thumbnail

      create_scaled_progressive_jpeg(thumb, blob, thumbnail_list, {height: 85, width: 85}, 'thumbnail_1')
      create_scaled_progressive_jpeg(thumb, blob, thumbnail_list, {height: 170, width: 170}, 'thumbnail_2')
      create_scaled_progressive_jpeg(thumb, blob, thumbnail_list, {height: 340, width: 340}, 'thumbnail_3')
      create_scaled_progressive_jpeg(thumb, blob, thumbnail_list, {width: 500}, 'thumbnail_4')
      create_scaled_progressive_jpeg(thumb, blob, thumbnail_list, {width: 1000}, 'thumbnail_5')
    end

    # Create or update a PDF file.
    # Should only be called when Msword Files are uploaded.
    def create_pdf_file
      title = "#{core.title} pdf"
      desc = "PDF for #{core.pid}"

      if self.core.content_objects.find { |e| e.instance_of? PdfFile }
        original = self.core.content_objects.find { |e| e.instance_of? PdfFile }
        pdf = update_or_create_with_metadata(title, desc, PdfFile, original)
      else
        pdf = update_or_create_with_metadata(title, desc, PdfFile)
      end

      master.transform_datastream(:content, { to_pdf: { format: 'pdf', datastream: 'pdf'} }, processor: 'document')
      pdf.add_file(master.pdf.content, 'content', "#{master.content.label.split('.').first}.pdf")
      pdf.original_filename = "#{master.content.label.split('.').first}.pdf"
      pdf.save! ? pdf : false
    end

    def create_scaled_progressive_jpeg(thumb, blob, thumbnail_list, size, dsid)

      if (master.is_a? ImageMasterFile) && !(master.width.first.to_i >= size[:width])
        return false
      end

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

    def update_or_create_with_metadata(title, desc, klass, object = nil)
      if object.nil?
        object = klass.new(pid: Drs::Noid.namespaceize(Drs::IdService.mint))
      end

      object.title                  = title
      object.identifier             = object.pid
      object.description            = desc
      object.keywords               = core.keywords.flatten unless core.keywords.nil?
      object.depositor              = core.depositor
      object.proxy_uploader         = core.proxy_uploader
      object.core_record            = core
      object.rightsMetadata.content = master.rightsMetadata.content
      object.save! ? object : false
    end

    def find_or_create_thumbnail
      title = "#{core.title} thumbnails"
      desc = "Thumbnails for #{core.pid}"

      if self.core.thumbnail
        update_or_create_with_metadata(title, desc, ImageThumbnailFile, self.core.thumbnail)
      else
        update_or_create_with_metadata(title, desc, ImageThumbnailFile)
      end
    end
end
