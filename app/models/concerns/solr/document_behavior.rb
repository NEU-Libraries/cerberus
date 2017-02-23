module Solr::DocumentBehavior
  def parent
    parent = first(Solrizer.solr_name("member_of_collection_ids", :symbol))

    if parent.blank?
      # isPartOf_ssim
      parent = first(Solrizer.solr_name("isPartOf", :symbol))
    end

    return parent
  end

  def title
    first(Solrizer.solr_name("title", :stored_searchable))
  end
end
