module PdfMetadataHelper
  def update_pdf_exif_metadata
    begin
      if !self.core_record.blank? && !self.core_record.pid.blank?
        require 'mini_exiftool'
        MiniExiftool.command = "#{Cerberus::Application.config.minitool_path}"
        pdf = MiniExiftool.new(self.fedora_file_path)

        cf = CoreFile.find(self.core_record.pid)
        doc = SolrDocument.new cf.to_solr

        updated_title = "#{doc.non_sort} #{doc.title}".strip

        if !updated_title.blank?
          pdf.title = "#{doc.non_sort} #{doc.title}".strip
          pdf.author = doc.author
          pdf.keywords = doc.keyword_list

          pdf.save!
        end
      end
    rescue Exception => error
      # PDF Metadata for google search is a nicety - if we error out, move on
    end
  end
end
