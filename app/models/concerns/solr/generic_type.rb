module Solr::GenericType
  def to_solr(solr_doc={})
    super.tap do |solr_doc|
      if ["Community", "Collection", "Compilation"].include? solr_doc['has_model_ssim'].first.to_s
        Solrizer.set_field(solr_doc, 'generic_type', 'Set', :stored_searchable)
      else
        Solrizer.set_field(solr_doc, 'generic_type', 'Work', :stored_searchable)
      end
    end
  end
end
