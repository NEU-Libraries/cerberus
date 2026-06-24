# frozen_string_literal: true

class SolrDocument
  # Provides highlight_field / has_highlight_field? (used for the "Full Text
  # Match" result snippet over all_text_timv) — both defined on this base module.
  include Blacklight::Solr::Document

  # self.unique_key = 'id'

  # The Email / SMS document extensions are intentionally not registered: the
  # catalog#email/#sms send routes are unmounted (authorization audit G5), so
  # the to_email_text / to_sms_text helpers they add would be dead code.

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Document::SemanticFields#field_semantics
  # and Blacklight::Document::SemanticFields#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  use_extension(Blacklight::Document::DublinCore)

  attribute :klass_type, Blacklight::Types::String, 'internal_resource_tesim'
  attribute :alternate_ids, Blacklight::Types::Array, 'alternate_ids_tesim'
  attribute :thumbnail_ssi, Blacklight::Types::String, 'thumbnail_ssi'
  attribute :thumbnail_2x_ssi, Blacklight::Types::String, 'thumbnail_2x_ssi'
  # Destination for a synthetic navigation row (e.g. a community's "Faculty &
  # Staff" entry), which has no per-type show route. url_for_document honours it.
  attribute :nav_url, Blacklight::Types::String, 'nav_url_ssi'

  def klass
    klass_type.presence&.constantize
  end

  # A genre-showcase ("Featured") Collection — Atlas projects the resource's
  # showcase flag onto featured_bsi. Drives the "Featured" thumbnail pill that
  # distinguishes curated showcases from ordinary child collections (v1 parity).
  # Solr returns a JSON boolean; coerce defensively for string-typed responses.
  def featured?
    value = self['featured_bsi']
    value == true || value.to_s == 'true'
  end

  # A depositor's personal-root Collection — Atlas flags it personal_root_bsi.
  # A structural container, not content: excluded from the global catalog index
  # and replaced (by the owning Person) in workspace-item breadcrumbs. Solr
  # returns a JSON boolean; coerce defensively for string-typed responses.
  def personal_root?
    value = self['personal_root_bsi']
    value == true || value.to_s == 'true'
  end

  def to_param
    raw = alternate_ids&.first
    noid = raw.split('id-').last if raw.present?
    return noid if noid.present?

    super
  end
end
