SitemapGenerator::Sitemap.default_host = "https://repository.library.northeastern.edu"
SitemapGenerator::Sitemap.create do
  query_string = "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:CoreFile\""
  row_count = ActiveFedora::SolrService.count(query_string)
  query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

  query_result.each_with_index do |search_result, i|
    begin
      pid = query_result[i]["id"]
      doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      if doc.public?
        # Is title unique? - Lets not put in super low value metadata explicitly to google
        # as it may have a negative affect on our research materials. i.e. IPTC items from
        # MarCom and D'Amore with the same title over and over for a photoset - Google gets
        # rightfully mad about canonical items
        if ActiveFedora::SolrService.count("title_info_title_tesim:\"#{doc.title}\"") <= 1
          add core_file_path(doc.pid), :lastmod => doc.updated_at
        end
      end
    rescue Exception => error
      #
    end
  end
end
