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

  attribute :klass_type, Blacklight::Types::String, 'internal_resource_tesim'
  attribute :alternate_ids, Blacklight::Types::Array, 'alternate_ids_tesim'
  attribute :uuid, Blacklight::Types::String, 'thumbnail_tesim'

  def klass
    klass_type.presence&.constantize
  end

  def to_param
    raw = alternate_ids&.first
    noid = raw.split('id-').last if raw.present?
    return noid if noid.present?

    super
  end
end
