# frozen_string_literal: true

# Resolves the full structural-home descendant NOID set of a container — itself,
# every descendant Collection/Community, and every Work homed in any of them.
# See docs/narrowing.md.
#
# Queries Solr DIRECTLY (no SearchBuilder / gated discovery): callers are system
# analytics and visibility repair, which must see every resource regardless of
# who is asking. Structural home only (include_linked: false) — a Work's
# impressions accrue to its canonical-home subtree, never to a Collection it is
# merely linked into.
class ContainerDescendantsQuery
  CONTAINER_TYPES = 'internal_resource_tesim:(Collection OR Community)'
  WORK_TYPE       = 'internal_resource_tesim:Work'
  MAX_ROWS        = 100_000

  def initialize(noid:, uuid:)
    @noid = noid.to_s.delete_prefix('id-')
    @uuid = uuid
  end

  def noids
    (container_noids + work_noids).uniq
  end

  def container_noids
    [@noid, *descendant_containers.filter_map { |doc| doc_noid(doc) }].uniq
  end

  def work_noids
    @work_noids ||= member_work_noids([@uuid, *descendant_containers.map(&:id)])
  end

  def container_uuids
    [@uuid, *descendant_containers.map(&:id)].uniq
  end

  def subtree_fq
    uuids = container_uuids
    MembershipQuery.any_of([MembershipQuery.identity_fq(uuids),
                            *MembershipQuery.member_clauses(uuids, include_linked: false)])
  end

  private

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
