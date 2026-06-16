# frozen_string_literal: true

# The container noids that already "cover" a Work for set-membership purposes:
# its structural parent chain, plus any collections it is linked into and their
# chains. A Set whose `included_collections` intersects this set already
# resolves the Work into its contents — so the Add-to-set picker can mark it
# already-included rather than offering a redundant direct add.
#
# This is the inverse of {SetResolver} (which goes set → contents): here we go
# Work → covering containers, mirroring the same include_linked, transitive
# membership. Works carry only their *direct* edges (`a_member_of_ssi` +
# `a_linked_member_of_ssim`); the full ancestor chain is denormalized onto the
# container docs (`ancestor_ids_ssim`), so it takes two gated lookups: the
# Work's edges, then the edge containers' own noid + ancestor chain.
class SetItemCoverage
  def self.call(noid:, search_service:)
    new(noid, search_service).call
  end

  def initialize(noid, search_service)
    @noid = noid
    @search_service = search_service
  end

  # @return [Set<String>] bare container noids covering the Work (empty when it
  #   has no resolvable parent/linked containers, e.g. an orphan).
  def call
    container_uuids = work_container_uuids
    return Set.new if container_uuids.empty?

    container_docs(container_uuids).each_with_object(Set.new) do |doc, covering|
      covering << noid_of(doc)
      covering.merge(Array(doc[MembershipQuery::ANCESTOR_FIELD]))
    end
  end

  private

    # The Work's direct structural parent + any linked-into containers, as bare
    # uuids — the edges live on the Work doc; their ancestor chains are fetched
    # from the container docs next.
    def work_container_uuids
      doc = search("{!terms f=alternate_ids_ssim}id-#{@noid}",
                   rows: 1,
                   fl:   "#{MembershipQuery::STRUCTURAL_FIELD},#{MembershipQuery::LINKED_FIELD}").documents.first
      return [] if doc.nil?

      edges = [doc[MembershipQuery::STRUCTURAL_FIELD]] + Array(doc[MembershipQuery::LINKED_FIELD])
      edges.compact.map { |ref| ref.to_s.delete_prefix('id-') }.uniq
    end

    def container_docs(uuids)
      search(MembershipQuery.identity_fq(uuids),
             rows: uuids.size,
             fl:   "alternate_ids_ssim,#{MembershipQuery::ANCESTOR_FIELD}").documents
    end

    def noid_of(doc)
      Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-')
    end

    # Gated search (mirrors SetResolver#search) — a container the user can't
    # discover never contributes to coverage.
    def search(*filter_queries, **extra)
      builder = @search_service.search_builder.with({}).with_filters(*filter_queries)
      builder = builder.merge(**extra) if extra.any?
      Blacklight.default_index.search(builder)
    end
end
