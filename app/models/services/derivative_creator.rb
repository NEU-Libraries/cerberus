include Cerberus::ThumbnailCreation

class DerivativeCreator

  attr_accessor :core, :master

  def initialize(master_pid)
    self.master = ActiveFedora::Base.find(master_pid, cast: true)
    self.core = CoreFile.find(self.master.core_record.pid)
  end

  def generate_derivatives

    master_file_path = ""

    if self.master.instance_of?(MswordFile)
      pdf = create_pdf_file
      pdf.transform_datastream(:content, content: { datastream: 'content', size: '1000x1000>' })
      master_file_path = pdf.fedora_file_path
    elsif self.master.instance_of?(PdfFile)
      copy = self.master
      copy.transform_datastream(:content, content: { datastream: 'content', size: '1000x1000>' })
      master_file_path = copy.fedora_file_path
    elsif self.master.instance_of?(ImageMasterFile)
      master_file_path = self.master.fedora_file_path
    end

    if !master_file_path.blank?
      thumb_pid = find_or_create_thumbnail
      create_all_thumbnail_sizes(master_file_path, thumb_pid)
    end

    thumbnail_list = []

    if self.core.thumbnail.datastreams["thumbnail_1"].content != nil
      for i in 1..5 do
        thumbnail_list << "/downloads/#{self.core.thumbnail.pid}?datastream_id=thumbnail_#{i}"
      end
    end

    @core.thumbnail_list = thumbnail_list
    @core.save!

  end

  private

    # Create or update a PDF file.
    # Should only be called when Msword Files are uploaded.
    def create_pdf_file
      title = "#{self.core.title} pdf"
      desc = "PDF for #{self.core.pid}"

      if self.core.content_objects.find { |e| e.instance_of? PdfFile }
        original = self.core.content_objects.find { |e| e.instance_of? PdfFile }
        pdf_pid = update_or_create_with_metadata(title, desc, PdfFile, original)
      else
        pdf_pid = update_or_create_with_metadata(title, desc, PdfFile)
      end

      pdf = ActiveFedora::Base.find("#{pdf_pid}", cast: true)

      self.master.transform_datastream(:content, { to_pdf: { format: 'pdf', datastream: 'pdf'} }, processor: 'document')
      pdf.add_file(self.master.pdf.content, 'content', "#{self.master.content.label.split('.').first}.pdf")
      pdf.original_filename = "#{self.master.content.label.split('.').first}.pdf"
      pdf.save! ? pdf : false
    end

    def update_or_create_with_metadata(title, desc, klass, object = nil)
      if object.nil?
        object = klass.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
      end

      object.title                  = title
      object.identifier             = object.pid
      object.description            = desc
      object.keywords               = self.core.keywords.flatten unless self.core.keywords.nil?
      object.depositor              = self.core.depositor
      object.proxy_uploader         = self.core.proxy_uploader
      object.core_record            = self.core
      object.rightsMetadata.content = self.core.rightsMetadata.content
      object.save!

      return object.pid
    end

    def find_or_create_thumbnail
      title = "#{self.core.title} thumbnails"
      desc = "Thumbnails for #{self.core.pid}"

      if self.core.thumbnail
        update_or_create_with_metadata(title, desc, ImageThumbnailFile, self.core.thumbnail)
      else
        update_or_create_with_metadata(title, desc, ImageThumbnailFile)
      end
    end

end
