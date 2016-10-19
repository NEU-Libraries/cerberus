Sitemap::Generator.instance.load :host => "repository.library.northeastern.edu", :protocol => "https" do

  query_string = "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:CoreFile\""
  row_count = ActiveFedora::SolrService.count(query_string)
  query_result = ActiveFedora::SolrService.query(query_string, :fl => "id", :rows => row_count)

  query_result.each_with_index do |search_result, i|
    begin
      pid = query_result[i]["id"]
      doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      if doc.public?
        # If ETD, add PDF
        if doc.category == "Theses and Dissertations" || doc.category == "Technical Reports" || doc.category == "Research Publications"
          if !doc.canonical_object.first.embargo_date_in_effect?
            content_doc = doc.canonical_object.first
            literal core_file_path(doc.pid), priority: 1, change_frequency: 'weekly', updated_at: doc.updated_at, metadata: { type: "text/html" }, link: { href: file_fulltext_path(doc.pid), rel: 'content', hash:content_doc.checksum, length: content_doc.file_size, type: content_doc.mime_type }
          end
        else
          literal core_file_path(doc.pid), priority: 1, change_frequency: 'weekly', updated_at: doc.updated_at, metadata: { type: "text/html" }
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
        # literal polymorphic_path(doc), priority: 1, change_frequency: 'weekly', updated_at: doc.updated_at, metadata: { type: "text/html" }
      end
    rescue Exception => error
      #
    end
  end

end
