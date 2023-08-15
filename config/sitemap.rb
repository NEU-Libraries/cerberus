SitemapGenerator::Sitemap.default_host = "https://repository.library.northeastern.edu"
SitemapGenerator::Sitemap.create do
  # query_string = "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:CoreFile\""
  query_string = "drs_category_ssim:\"Research Publications\" OR drs_category_ssim:\"Theses and Dissertations\" OR drs_category_ssim:\"Technical Reports\""
  row_count = ActiveFedora::SolrService.count(query_string)
  query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

  query_result.each do |search_result|
    begin
      pid = search_result["id"]
      doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      if doc.public?
        # Is title unique? - Lets not put in super low value metadata explicitly to google
        # as it may have a negative affect on our research materials. i.e. IPTC items from
        # MarCom and D'Amore with the same title over and over for a photoset - Google gets
        # rightfully mad about canonical items
        # if ActiveFedora::SolrService.count("title_info_title_tesim:\"#{doc.title}\"") <= 1
        #   add core_file_path(doc.pid), :lastmod => doc.updated_at
        # end

        # warm cache
        Rails.cache.fetch("/mods/#{doc.pid}-#{doc.updated_at}", :expires_in => 5.days) do
          Sanitize.clean(Kramdown::Document.new(CoreFilesController.new.render_mods_display(CoreFile.find(doc.pid))).to_html, :elements => ['sup', 'sub', 'dt', 'dd', 'br', 'a'], :attributes => {'a' => ['href']}).html_safe
        end

        add core_file_path(doc.pid), :lastmod => doc.updated_at
      end
    rescue Exception => error
      #
    end
  end
end
