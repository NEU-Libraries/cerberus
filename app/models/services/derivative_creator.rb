require 'RMagick'
include Magick

class DerivativeCreator

  attr_accessor :core, :master, :thumbnail_list

  def initialize(master_pid)
    @master = ActiveFedora::Base.find(master_pid, cast: true)
    @core = NuCoreFile.find(@master.core_record.pid)
    @thumbnail_list = Array.new
  end

  def generate_derivatives
    if master.instance_of? ImageMasterFile
      create_full_thumbnail
    elsif master.instance_of? PdfFile
      create_thumbnail_from_pdf(self.master)
    elsif master.instance_of? MswordFile
      pdf = create_pdf_file
      create_thumbnail_from_pdf(pdf)
    elsif master.instance_of? VideoFile
      create_thumbnail_from_poster
    end

    @core.reload
    @core.thumbnail_list = @thumbnail_list
    @core.save!
  end

  private

    def create_thumbnail_from_poster
      thumbnail = find_or_create_thumbnail

      create_scaled_progressive_jpeg(thumbnail, master, {height: 85, width: 85}, 'thumbnail_1', true)
      create_scaled_progressive_jpeg(thumbnail, master, {height: 170, width: 170}, 'thumbnail_2', true)
      create_scaled_progressive_jpeg(thumbnail, master, {height: 340, width: 340}, 'thumbnail_3', true)
      create_scaled_progressive_jpeg(thumbnail, master, {width: 500}, 'thumbnail_4', true)
      create_scaled_progressive_jpeg(thumbnail, master, {width: 1000}, 'thumbnail_5', true)
    end

    def create_thumbnail_from_pdf(pdf)
      thumbnail = find_or_create_thumbnail

      # Modify the copy of the object we're holding /without/ persisting that change.
      pdf.transform_datastream(:content, content: { datastream: 'content', size: '1000x1000>' })

      create_scaled_progressive_jpeg(thumbnail, pdf, {height: 85, width: 85}, 'thumbnail_1')
      create_scaled_progressive_jpeg(thumbnail, pdf, {height: 170, width: 170}, 'thumbnail_2')
      create_scaled_progressive_jpeg(thumbnail, pdf, {height: 340, width: 340}, 'thumbnail_3')
      create_scaled_progressive_jpeg(thumbnail, pdf, {width: 500}, 'thumbnail_4')
      create_scaled_progressive_jpeg(thumbnail, pdf, {width: 1000}, 'thumbnail_5')
    end

    # Creates a thumbnail with as many datastreams as possible.
    # Used exclusively for images.
    def create_full_thumbnail(master = @master)
      thumbnail = find_or_create_thumbnail

      create_scaled_progressive_jpeg(thumbnail, master, {height: 85, width: 85}, 'thumbnail_1')
      create_scaled_progressive_jpeg(thumbnail, master, {height: 170, width: 170}, 'thumbnail_2')
      create_scaled_progressive_jpeg(thumbnail, master, {height: 340, width: 340}, 'thumbnail_3')
      create_scaled_progressive_jpeg(thumbnail, master, {width: 500}, 'thumbnail_4')
      create_scaled_progressive_jpeg(thumbnail, master, {width: 1000}, 'thumbnail_5')
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
      pdf.save! ? pdf : false
    end

    def create_scaled_progressive_jpeg(thumb, master, size, dsid, poster = false)
      if (master.is_a? ImageMasterFile) && !(master.width.first.to_i >= size[:width])
        return false
      end

      if !poster
        blob = master.content.content
      else
        blob = master.poster.content
      end

      if master.content.content.instance_of? (StringIO)
        blob = blob.string
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

      thumb.add_file(end_img.to_blob, dsid, "#{master.content.label.split('.').first}.jpeg")
      thumb.save!

      self.thumbnail_list << "/downloads/#{self.core.thumbnail.pid}?datastream_id=#{dsid}"
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
