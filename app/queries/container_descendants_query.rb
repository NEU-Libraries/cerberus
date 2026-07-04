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

  # @return [Array<String>] the container's own noid + all descendant noids.
  def noids
    descendant_containers = container_docs
    container_uuids = descendant_containers.map(&:id)
    container_noids = descendant_containers.filter_map { |doc| doc_noid(doc) }

    ([@noid] + container_noids + member_work_noids([@uuid, *container_uuids])).uniq
  end

  private

    def container_docs
      solr(MembershipQuery.descendants_fq(@noid), CONTAINER_TYPES)
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
