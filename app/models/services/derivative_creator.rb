require 'RMagick'
include Magick

class DerivativeCreator 

  attr_accessor :core, :master

  def initialize(master_pid) 
    @master = ActiveFedora::Base.find(master_pid, cast: true) 
    @core = NuCoreFile.find(@master.core_record.pid) 
  end

  def generate_derivatives
    if master.instance_of? ImageMasterFile 
      create_full_thumbnail 
    # This will have to wait until after Thanksgiving
    # elsif master.instance_of? PdfFile 
    #   create_minimum_thumbnail 
    # elsif master.instance_of? MswordFile 
    #   pdf = create_pdf_file
    #   create_minimum_thumbnail(pdf)
    end
  end

  private 

    # Creates a thumbnail with as many datastreams as possible. 
    # Used exclusively for images. 
    def create_full_thumbnail(master = @master)
      if self.core.thumbnail 
        thumbnail = self.core.thumbnail 
      else
        thumbnail = instantiate_with_metadata("#{core.title} thumbnails", "Thumbnails for #{core.pid}", ImageThumbnailFile)
      end

      create_scaled_progressive_jpeg(thumbnail, master, {height: 170, width: 170}, 'thumbnail_2') 
      create_scaled_progressive_jpeg(thumbnail, master, {height: 340, width: 340}, 'thumbnail_2_2x') 
      create_scaled_progressive_jpeg(thumbnail, master, {width: 340}, 'thumbnail_4') 
      create_scaled_progressive_jpeg(thumbnail, master, {width: 680}, 'thumbnail_4_2x') 
      create_scaled_progressive_jpeg(thumbnail, master, {width: 970}, 'thumbnail_10')
      create_scaled_progressive_jpeg(thumbnail, master, {width: 1940}, 'thumbnail_10_2x')
    end

    def create_minimum_thumbnail(master = @master) 
      self.core.thumbnail.delete if self.core.thumbnail 
      thumbnail = instantiate_with_metadata("#{core.title} thumbnails", "Thumbnails for #{core.pid}", ImageThumbnailFile)
    end

    def create_pdf_file 
      # Delete a PDF record if one exists for this core file already 
      old_pdf = core.content_objects.find { |x| x.instance_of? PdfFile }
      old_pdf.delete if pdf 

      pdf = instantiate_with_metadata("#{core.title} pdf", "PDF for #{core.pid}", PdfFile) 
    end

    def instantiate_with_metadata(title, desc, klass) 
      @core.pid 
      puts @master
      object = klass.new(pid: Sufia::Noid.namespaceize(Sufia::IdService.mint))
      object.title                  = title 
      object.identifier             = object.pid
      object.description            = desc
      object.keywords               = core.keywords  
      object.depositor              = core.depositor
      object.core_record            = core  
      object.rightsMetadata.content = master.rightsMetadata.content
      object.save! ? object : false
    end

    def create_scaled_progressive_jpeg(thumb, master, size, dsid)
      if (master.is_a? ImageMasterFile) && !(master.width.first.to_i >= size[:width]) 
        return false 
      end

      begin 
        tmp = Tempfile.new('thumb', encoding: 'ascii-8bit')
        tmp.write master.content.content 

        img = Magick::Image.read(tmp.path).first 
        img.format = "JPEG" 
        if size[:height] && size[:width]
          scaled_img = img.resize_to_fill(size[:height], size[:width]) 
        elsif size[:width] 
          scaled_img = img.resize_to_fit(size[:width])
        else 
          raise "size must be hash containing :height/:width keys or just the :width key" 
        end

        scaled_img.write(tmp.path) { self.interlace = Magick::PlaneInterlace }

        thumb.add_file(File.open(tmp.path, 'rb').read, dsid, 'test.jpeg') 
        thumb.save!
      ensure 
        tmp.unlink 
      end
    end   
end