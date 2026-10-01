# frozen_string_literal: true

# The resources a cascading delete withdraws, deepest first and the container
# last, because Atlas refuses to tombstone a container with live members. See
# docs/admin.md ("Deleting a container that is not empty").
#
# The narrowing walk with two differences: a community can hold communities, so
# they are included, and anything already withdrawn is left out. That keeps an
# item withdrawn earlier off this cascade's list, so a restore from the list
# never brings it back.
class TombstoneTargets < NarrowingTargets
  TYPES = 'internal_resource_tesim:(Work OR Collection OR Community)'
  LIVE  = '-tombstoned_bsi:true'

  # Above this the delete stops and asks for the development team. A cascade
  # that size is the one to take slowly, and a single query must see it whole.
  LIMIT = NarrowingImpact::CASCADE_LIMIT

  # Live items beneath the container, by type, for the confirmation. The
  # container itself is not counted.
  #
  # internal_resource_tesim is tokenized, so Solr facets it lowercased.
  # @return [Hash{String => Integer}] e.g. { 'Work' => 412, 'Collection' => 3, 'Community' => 0 }
  def counts
    @counts ||= begin
      facet = SolrFacetValues.call(field:    'internal_resource_tesim',
                                   extra_fq: [*filters, "-id:\"#{@uuid}\""]).to_h
      %w[Work Collection Community].index_with { |type| facet[type.downcase].to_i }
    end
  end

  def total
    counts.values.sum
  end

  def over_limit?
    total > LIMIT
  end

  private

    def filters
      [subtree_fq, TYPES, LIVE]
    end
end
