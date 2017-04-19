class FeaturedWorkIndexer < ActiveFedora::IndexingService
  def generate_solr_document
    super.tap do |solr_doc|
      Solrizer.set_field(solr_doc, 'generic_type', 'Featured', :stored_searchable)
    end
  end
end
