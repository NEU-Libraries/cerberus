class CommunityIndexer < ActiveFedora::IndexingService
  include IndexesThumbnails

  self.thumbnail_path_service = ThumbnailPathService
  def generate_solr_document
    super.tap do |solr_doc|
      Solrizer.set_field(solr_doc, 'generic_type', 'Set', :stored_searchable)
    end
  end
end
