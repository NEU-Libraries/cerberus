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
            # If ETD, add PDF
            if doc.category == "Theses and Dissertations" || doc.category == "Technical Reports" || doc.category == "Research Publications"
              if !doc.canonical_object.first.embargo_date_in_effect?
                # add download_path(doc.canonical_object.first.pid, {datastream_id: 'content'})
                add file_fulltext_path(doc.pid)
              end
            end
          end
        rescue Exception => error
          #
        end
      end

      # Add collections and communities
      query_string = "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:Community\" OR #{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:Collection\""
      row_count = ActiveFedora::SolrService.count(query_string)
      query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

      query_result.each_with_index do |search_result, i|
        begin
          pid = query_result[i]["id"]
          doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
          if doc.public?
            add polymorphic_path(doc)
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
