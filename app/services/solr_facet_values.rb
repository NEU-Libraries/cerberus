# frozen_string_literal: true

# Enumerates the current values of a Solr facet field directly (no
# SearchBuilder / gated discovery — same un-gated posture as
# ContainerDescendantsQuery and ImpressionsReport#resolve: admin analytics
# reads system-wide). Backs the Usage Analytics "facet by Content type"
# picker — mirrors the catalog's own "Content" facet (classification_ssim,
# see project_content_facet design) but only enumerates values; it doesn't
# run a search itself.
class SolrFacetValues < ApplicationService
  MAX_VALUES = 200

  # @param field [String] the Solr facet field (e.g. 'classification_ssim').
  # @param extra_fq [Array<String>] additional filter queries to scope the
  #   enumeration (e.g. restrict to Works only).
  def initialize(field:, extra_fq: [])
    @field = field
    @extra_fq = extra_fq
    super()
  end

  # @return [Array<Array(String, Integer)>] [value, count] pairs, Solr's
  #   default count-descending order.
  def call
    response = Blacklight.default_index.search(
      q: '*:*', fq: @extra_fq, rows: 0,
      'facet' => true, 'facet.field' => @field, 'facet.limit' => MAX_VALUES
    )
    Array(response.facet_fields[@field]).each_slice(2).to_a
  end
end
