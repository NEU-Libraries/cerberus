# frozen_string_literal: true
class SolrDocument
  include Blacklight::Solr::Document

  # self.unique_key = 'id'

  # Email uses the semantic field mappings below to generate the body of an email.
  SolrDocument.use_extension(Blacklight::Document::Email)

  # SMS uses the semantic field mappings below to generate the body of an SMS email.
  SolrDocument.use_extension(Blacklight::Document::Sms)

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Document::SemanticFields#field_semantics
  # and Blacklight::Document::SemanticFields#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  use_extension(Blacklight::Document::DublinCore)

  # Do content negotiation for AF models.

  use_extension( Hydra::ContentNegotiation )

  def parent
    # member_of_collection_ids_ssim
    parent = self[Solrizer.solr_name("member_of_collection_ids", :symbol)]

    if parent.blank?
      # isPartOf_ssim
      parent = self[Solrizer.solr_name("isPartOf", :symbol)]
    end

    if parent.blank?
      return nil
    else
      return parent.first
    end
  end

  def title
    title = self[Solrizer.solr_name("title", :stored_searchable)]

    if title.blank?
      return ""
    else
      return title.first
    end
  end
end
