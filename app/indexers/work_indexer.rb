class WorkIndexer < ActiveFedora::IndexingService
  def generate_solr_document
    super.tap do |solr_doc|
      Solrizer.set_field(solr_doc, 'generic_type', 'Work', :stored_searchable)

      if !object.parent.blank?
        solr_doc[Solrizer.solr_name('member_of_collection_ids', :symbol)] = object.parent.id
      end

      if !object.file_sets.blank? && !object.file_sets.first.jp2.blank?
        id = object.file_sets.first.jp2.id
        pair_tree = id.first(8).scan(/.{2}/).join("/")
        loris_path = Rails.application.config.loris_path
        # jp2 path
        solr_doc[Solrizer.solr_name('loris_url', :symbol)] = loris_path + CGI::escape(pair_tree) + "/" + CGI::escape(id) + "/"
      end
    end
  end
end
