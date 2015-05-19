namespace :sitemap do
  desc "Generates sitemap"
  task :generate do
    SitemapGenerator::Sitemap.default_host = 'https://repository.library.northeastern.edu/'

    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

    SitemapGenerator::Sitemap.create do
      add '/'

    end
    if Rails.env.production?
      SitemapGenerator::Sitemap.ping_search_engines
    end
  end
end
