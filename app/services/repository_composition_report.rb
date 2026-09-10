# frozen_string_literal: true

# Inventory counts for the Usage Analytics "Composition" tab, repo-wide or
# scoped to one subtree. Counts are deliberately un-gated (system-wide
# search, no SearchBuilder): an inventory must include every resource
# regardless of the viewer's own visibility. See docs/analytics.md.
class RepositoryCompositionReport
  ENTITY_TYPES = %w[Community Collection Work Person].freeze

  def initialize(scope_fq: nil)
    @scope_fq = scope_fq
  end

  # `internal_resource_tesim` is tokenized text, so Solr facets it over
  # lowercased tokens ("work", "collection"): the facet lookup needs the
  # downcased key. Filter queries on the same field match either case.
  def entity_counts
    @entity_counts ||= begin
      facet = SolrFacetValues.call(field: 'internal_resource_tesim', extra_fq: scope_filters).to_h
      ENTITY_TYPES.index_with { |type| facet[type.downcase].to_i }
    end
  end

  def work_visibility
    @work_visibility ||= begin
      public_count = count(filters: ['internal_resource_tesim:Work', 'read_access_group_ssim:public',
                                     *scope_filters])
      { public: public_count, private: entity_counts['Work'] - public_count }
    end
  end

  # Multivalued: a mixed-media Work counts under every classification it
  # holds, so these never sum to entity_counts' Work total.
  def classification_counts
    @classification_counts ||= SolrFacetValues.call(
      field: 'classification_ssim', extra_fq: ['internal_resource_tesim:Work', *scope_filters]
    )
  end

  private

    def scope_filters
      Array(@scope_fq)
    end

    def count(filters:)
      Blacklight.default_index.search(q: '*:*', fq: filters, rows: 0).total
    end
end
