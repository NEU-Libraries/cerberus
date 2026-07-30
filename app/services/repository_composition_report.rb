# frozen_string_literal: true

# Repository-wide composition/inventory stats for the Usage Analytics
# dashboard's "Composition" tab — v1 had a flat table of entity counts + a
# file-type breakdown; this is the v2-data-shape equivalent in substance,
# not a literal port (see the two gaps noted below). Otherwise repo-wide:
# unlike the rest of the dashboard, composition isn't a traffic metric, so
# it ignores the date range and segment regardless of scope_fq — there is
# no "composition of the last 90 days," only "composition of this subtree
# (or the whole repository)."
#
# Un-gated (system-wide Blacklight.default_index.search, no SearchBuilder),
# the same posture as ContainerDescendantsQuery / ImpressionsReport /
# SolrFacetValues — an inventory count must include every resource
# regardless of the viewer's own visibility.
#
# Two v1 stats have no v2 equivalent and are deliberately omitted rather
# than faked:
# - "Users" (raw SSO account count) — no atlas_rb binding exists to list or
#   count Atlas's users table (System::User only supports find/create by
#   NUID); see the gap report.
# - Per-format breakdown (PDF vs Word, real Zip vs generic) — Atlas's
#   ClassificationIndexer collapses both PDF and Word into "Text", and the
#   Label enum that *would* distinguish them is never projected to Solr.
#   classification_counts below reports the real v2 taxonomy instead of
#   forcing a v1-shaped split that doesn't exist.
class RepositoryCompositionReport
  ENTITY_TYPES = %w[Community Collection Work Person].freeze

  # @param scope_fq [String, nil] an additional raw fq fragment (e.g.
  #   {ContainerDescendantsQuery#subtree_fq}) restricting every count below to
  #   one container's subtree — nil (default) is unscoped, the repo-wide
  #   behavior the admin dashboard's Composition tab has always had. Person
  #   docs sit outside the structural containment tree subtree_fq matches, so
  #   a scoped entity_counts always reads 0 Person regardless of container —
  #   correct for a Collection (Person never belongs to one), a minor,
  #   accepted undercount for a Community.
  def initialize(scope_fq: nil)
    @scope_fq = scope_fq
  end

  # @return [Hash{String => Integer}] counts for ENTITY_TYPES, 0 for any
  #   type with no documents (rather than a missing key).
  #
  # `internal_resource_tesim` is a tokenized *text* field (the "tesim" Hydra
  # suffix), not a string field like classification_ssim — Solr facets a
  # text field over its lowercased indexed tokens ("work", "collection", ...),
  # even though `fq: 'internal_resource_tesim:Work'` filter queries still
  # match case-insensitively (the query analyzer lowercases too). Facet
  # lookups need the downcased key; filter queries don't.
  def entity_counts
    @entity_counts ||= begin
      facet = SolrFacetValues.call(field: 'internal_resource_tesim', extra_fq: scope_filters).to_h
      ENTITY_TYPES.index_with { |type| facet[type.downcase].to_i }
    end
  end

  # @return [Hash{Symbol => Integer}] :public / :private Work counts.
  # Measures discoverability (read_access_group_ssim includes 'public'), not
  # "downloadable right now" — an embargoed Work is still publicly
  # discoverable and counts as public here, matching v1's inventory framing.
  def work_visibility
    @work_visibility ||= begin
      public_count = count(filters: ['internal_resource_tesim:Work', 'read_access_group_ssim:public',
                                     *scope_filters])
      { public: public_count, private: entity_counts['Work'] - public_count }
    end
  end

  # @return [Array<Array(String, Integer)>] [classification, Work count]
  #   pairs, count-descending. Multivalued — a mixed-media Work counts
  #   under every classification it holds, so these don't sum to the Work
  #   total in entity_counts.
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
