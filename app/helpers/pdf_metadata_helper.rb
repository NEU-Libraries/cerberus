module PdfMetadataHelper
  def update_pdf_exif_metadata
    if !self.core_record.blank? && !self.core_record.pid.blank?
      require 'mini_exiftool'
      MiniExiftool.command = "#{Cerberus::Application.config.minitool_path}"
      pdf = MiniExiftool.new(self.fedora_file_path)

      cf = CoreFile.find(self.core_record.pid)
      doc = SolrDocument.new cf.to_solr

      pdf.title = "#{doc.non_sort} #{doc.title}".strip
      pdf.author = doc.author
      pdf.keywords = doc.keyword_list

      pdf.save!
    end
  end
end
