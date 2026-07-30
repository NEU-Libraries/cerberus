# frozen_string_literal: true

# Resolves the full structural-home descendant NOID set of a container — itself,
# every descendant Collection/Community, and every Work homed in any of them —
# for the impressions container rollup (RollupContainerImpressionsJob).
#
# Queries Solr DIRECTLY (no SearchBuilder / gated discovery): this is system
# analytics that must count every resource regardless of visibility. Structural
# home only (include_linked: false) — a Work's impressions accrue to its
# canonical-home subtree, never to a Collection it is merely linked into (the
# overlay is discovery-only; it never changes attribution). Reuses the proven
# MembershipQuery fq fragments (the same recipe as CatalogController#find_children).
class ContainerDescendantsQuery
  CONTAINER_TYPES = 'internal_resource_tesim:(Collection OR Community)'
  WORK_TYPE       = 'internal_resource_tesim:Work'
  MAX_ROWS        = 100_000

  # @param noid [String] the container's bare noid (the rollup key).
  # @param uuid [String] the container's Solr id (uuid), for member resolution.
  def initialize(noid:, uuid:)
    @noid = noid.to_s.delete_prefix('id-')
    @uuid = uuid
  end

  # @return [Array<String>] the container's own noid + all descendant noids
  #   (containers and works alike).
  def noids
    (container_noids + work_noids).uniq
  end

  # @return [Array<String>] the container's own noid + every descendant
  #   Collection/Community noid (no Works).
  def container_noids
    [@noid, *descendant_containers.filter_map { |doc| doc_noid(doc) }].uniq
  end

  # @return [Array<String>] every Work noid structurally homed under this
  #   container or any descendant container (no Collections/Communities).
  # Memoized alongside descendant_containers — ImpressionScope calls
  # container_noids/work_noids/noids on the same instance for different
  # report metrics, so each real query behind them runs at most once.
  def work_noids
    @work_noids ||= member_work_noids([@uuid, *descendant_containers.map(&:id)])
  end

  # @return [Array<String>] this container's own uuid + every descendant
  #   container's uuid (no Works) — the Solr `id` values behind #subtree_fq.
  def container_uuids
    [@uuid, *descendant_containers.map(&:id)].uniq
  end

  # @return [String] a Solr fq matching this container, every descendant
  #   container, and every Work structurally homed anywhere in the subtree —
  #   for constraining an arbitrary search/facet to "within this section of
  #   the tree" (the Collection/Community edit page's Analytics tab item
  #   lookup + composition), without materializing the full member list the
  #   way #noids does. Structural home only (include_linked: false), same
  #   attribution rule as the rest of this class.
  def subtree_fq
    uuids = container_uuids
    MembershipQuery.any_of([MembershipQuery.identity_fq(uuids),
                            *MembershipQuery.member_clauses(uuids, include_linked: false)])
  end

  private

    # Memoized so container_noids/work_noids/noids share one Solr round-trip
    # for the descendant-container lookup, however many are called.
    def descendant_containers
      @descendant_containers ||= solr(MembershipQuery.descendants_fq(@noid), CONTAINER_TYPES)
    end

    def member_work_noids(container_uuids)
      return [] if container_uuids.empty?

      solr(MembershipQuery.members_fq(container_uuids, include_linked: false), WORK_TYPE)
        .filter_map { |doc| doc_noid(doc) }
    end

    def doc_noid(doc)
      Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-')
    end

    def solr(*filter_queries)
      Blacklight.default_index.search(
        q: '*:*', fq: filter_queries, rows: MAX_ROWS, fl: 'id,alternate_ids_ssim'
      ).documents
    end
end
