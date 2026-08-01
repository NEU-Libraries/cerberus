# frozen_string_literal: true

# What narrowing a container's visibility would actually touch: how many
# descendants, and whose they are. Feeds both gates the caller needs — the
# count for the confirmation, the depositor set for the ownership rule.
#
# Answered with one rows:0 facet query rather than by materializing the subtree.
# Both questions are aggregate, and a Collection can hold thousands of Works, so
# there is nothing to gain by listing them here; the cascade job enumerates them
# when it actually has writes to issue.
#
# Queries Solr DIRECTLY, with no gated discovery — the same choice
# ContainerDescendantsQuery makes and for the same reason. A cascade has to see
# every descendant regardless of whether the acting user could discover it, or
# it would skip precisely the resources that are leaking.
class NarrowingImpact
  # Only resources that carry a read ACL of their own. Membership also returns a
  # Work's FileSets, whose visibility follows the Work rather than standing
  # alone; counting them would overstate the impact, and the metadata FileSet
  # carries no depositor at all, which would poison the ownership test below.
  AFFECTED_TYPES  = 'internal_resource_tesim:(Work OR Collection)'
  DEPOSITOR_FIELD = 'depositor_ssi'

  # Above this the cascade stops and asks for staff instead of running. The
  # cascade issues one PATCH per affected resource, so a subtree this size is a
  # job long enough that a half-finished run is the likely outcome — and a
  # partial narrowing is the leak this feature exists to close. Routing it to
  # the escalation path reuses an affordance that already has to exist.
  CASCADE_LIMIT = 10_000

  # @param noid [String] the container's bare noid.
  # @param uuid [String] the container's Solr id (uuid).
  def initialize(noid:, uuid:)
    @noid = noid.to_s.delete_prefix('id-')
    @uuid = uuid
  end

  # @return [Integer] affected descendants, excluding the container itself.
  def count
    facets.fetch(:count)
  end

  # @return [Hash{String=>Integer}] depositor NUID => affected resources.
  def depositors
    facets.fetch(:depositors)
  end

  def over_cap?
    count > CASCADE_LIMIT
  end

  # Whether every affected descendant belongs to this one depositor.
  #
  # A resource with no depositor is indexed without the field, so it never shows
  # up in the facet at all — comparing the facet total against the match count
  # is what catches it. Inspecting only the facet keys would let an unattributed
  # resource slide through as "all mine".
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

    # The subtree, restricted to resources with their own ACL, minus the
    # container itself — the caller is narrowing that one deliberately, so it is
    # not part of "what else this touches".
    def filters
      [subtree_fq, AFFECTED_TYPES,
       MembershipQuery.excluding_fq(MembershipQuery.identity_fq([@uuid]))]
    end

    def subtree_fq
      ContainerDescendantsQuery.new(noid: @noid, uuid: @uuid).subtree_fq
    end
end
