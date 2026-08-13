# frozen_string_literal: true

# A Work's typed associations with other Works, resolved to Solr documents the
# viewer is allowed to see.
#
# An association is a directed claim that one Work is the codebook, figure,
# transcription, instructional material or supplemental material *for* another.
# The edge is stored once, on the Work that asserts it; Atlas derives the other
# direction. So one Work's `outbound` is another's `inbound`, and the two can
# never disagree.
#
# **Atlas answers with noids, and that is what makes this safe.** Atlas's read
# floor is unconditional: the association endpoint reports every edge, including
# edges to Works the viewer must not see. Resolving those noids through the
# gated search turns the ungated edge list into only the rows this viewer may
# have — a noid that resolves to no document simply does not render. The same
# lookup drops tombstoned Works for free, since `-tombstoned_bsi:true` sits in
# the catalog's default_solr_params.
#
# A gated-away Work must leave no trace: no group header, no count, no "1 item
# hidden". Any of those confirm that a record exists, which is what the gate
# exists to prevent. Dropping the noid before the view ever sees it is what
# enforces that here.
#
# One Solr query covers both directions and every predicate, however many edges
# a Work has.
class WorkAssociations < ApplicationService
  DIRECTIONS = %w[outbound inbound].freeze

  # The resolved edges. Each direction is a Hash of predicate => documents, in
  # AtlasRb::Work::ASSOCIATION_TYPES order rather than Atlas's hash order, so
  # the box lists its groups the same way on every Work. A predicate whose every
  # edge was gated away is absent, not empty.
  Result = Struct.new(:outbound, :inbound) do
    def empty?
      outbound.empty? && inbound.empty?
    end

    # Every document across both directions, for a jump-link count that
    # matches what actually renders.
    def size
      (outbound.values + inbound.values).sum(&:size)
    end
  end

  # @param associations [Hash, nil] Atlas's reply from
  #   {AtlasRb::Work.associations} — `{"outbound" => {predicate => [noid]}, …}`.
  # @param search_service [Blacklight::SearchService] supplies the gated search
  #   builder and index (the controller's `search_service`).
  def initialize(associations:, search_service:)
    @associations = associations || {}
    @search_service = search_service
    super()
  end

  # @return [Result]
  def call
    return Result.new({}, {}) if noids.empty?

    Result.new(resolve('outbound'), resolve('inbound'))
  end

  private

    # One direction's predicates, each mapped to the documents that survived the
    # gate, with the empty groups dropped.
    def resolve(direction)
      edges = @associations[direction]
      return {} unless edges.is_a?(Hash)

      AtlasRb::Work::ASSOCIATION_TYPES.filter_map do |type|
        docs = Array(edges[type]).filter_map { |noid| documents_by_noid[noid.to_s] }
        [type, docs] if docs.any?
      end.to_h
    end

    # Every noid Atlas named, both directions, deduplicated — one Work can be
    # both the transcription of a Work and a figure for it, and a cycle between
    # two Works is permitted and meaningful.
    def noids
      @noids ||= DIRECTIONS.flat_map do |direction|
        edges = @associations[direction]
        edges.is_a?(Hash) ? edges.values.flatten : []
      end.map(&:to_s).uniq
    end

    # The gated lookup, keyed by bare noid. Solr stores the noid in
    # `alternate_ids_ssim` as `id-<noid>`; the same `{!terms}` shape
    # SetResolver#noun_uuids uses.
    def documents_by_noid
      @documents_by_noid ||= search.documents.index_by do |doc|
        Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-')
      end
    end

    # `with_filters` rather than a merged `:fq` — merging drops the
    # gated-discovery clause the search builder adds, which is the whole
    # protection this class depends on. Same plumbing as SetResolver#search.
    def search
      terms = noids.map { |noid| "id-#{noid}" }.join(',')
      builder = @search_service.search_builder
                               .with({})
                               .with_filters("{!terms f=alternate_ids_ssim}#{terms}")
                               .merge(rows: noids.size)
      Blacklight.default_index.search(builder)
    end
end
