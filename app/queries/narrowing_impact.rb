# frozen_string_literal: true

# What narrowing a container's visibility would touch: how many descendants, and
# whose they are. See docs/narrowing.md.
#
# Queries Solr DIRECTLY, never through gated discovery. A cascade has to see
# every descendant regardless of whether the acting user could discover it, or
# it skips precisely the resources that are leaking.
class NarrowingImpact
  # Only resources carrying a read ACL of their own. Adding FileSets would both
  # overstate the impact and poison the ownership test below — the metadata
  # FileSet carries no depositor.
  AFFECTED_TYPES  = 'internal_resource_tesim:(Work OR Collection)'
  DEPOSITOR_FIELD = 'depositor_ssi'

  # Above this the cascade stops and asks for staff instead of running. Raising
  # it buys a half-finished run, and a partial narrowing is the leak this
  # feature exists to close.
  CASCADE_LIMIT = 10_000

  def initialize(noid:, uuid:)
    @noid = noid.to_s.delete_prefix('id-')
    @uuid = uuid
  end

  def count
    facets.fetch(:count)
  end

  def depositors
    facets.fetch(:depositors)
  end

  def over_cap?
    count > CASCADE_LIMIT
  end

  # Whether every affected descendant belongs to this one depositor.
  #
  # Compare the facet total against the match count, not just the facet keys: a
  # resource with no depositor is indexed without the field, so it never appears
  # in the facet and would slide through as "all mine".
  def wholly_owned_by?(nuid)
    return false if nuid.blank?
    return true  if count.zero?

    depositors.keys == [nuid.to_s] && depositors.values.sum == count
  end

  private

    def facets
      @facets ||= begin
        response = Blacklight.default_index.search(
          q: '*:*', fq: filters, rows: 0,
          facet: true, 'facet.field': DEPOSITOR_FIELD, 'facet.mincount': 1
        )
        { count: response.total, depositors: facet_pairs(response) }
      end
    end

    # Solr returns facet fields as a flat [value, hits, value, hits, ...] array.
    def facet_pairs(response)
      flat = response.dig('facet_counts', 'facet_fields', DEPOSITOR_FIELD) || []
      flat.each_slice(2).to_h
    end

    def filters
      [subtree_fq, AFFECTED_TYPES,
       MembershipQuery.excluding_fq(MembershipQuery.identity_fq([@uuid]))]
    end

    def subtree_fq
      ContainerDescendantsQuery.new(noid: @noid, uuid: @uuid).subtree_fq
    end
end
