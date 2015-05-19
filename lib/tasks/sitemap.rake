namespace :sitemap do
  desc "Generates sitemap"
  task :generate => :environment do
    SitemapGenerator::Sitemap.default_host = 'https://repository.library.northeastern.edu'

    SitemapGenerator::Sitemap.create do

      query_string = "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:CoreFile\""
      row_count = ActiveFedora::SolrService.count(query_string)
      query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

      query_result.each_with_index do |search_result, i|
        begin
          pid = query_result[i]["id"]
          doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
          if doc.public?
            add core_file_path(doc.pid)
          end
        rescue Exception => error
          #
        end
      end

    end

    if Rails.env.production?
      SitemapGenerator::Sitemap.ping_search_engines
    end
    
  end
end
