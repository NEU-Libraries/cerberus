# frozen_string_literal: true

# A Work's typed associations, resolved through the GATED search to only the
# documents this viewer may see. Atlas's association endpoint is ungated and
# names every edge, so a gated-away Work must leave no trace here: no group
# header, no count, no "1 item hidden" — each of those confirms the record
# exists, which is what the gate prevents. See docs/edit-surfaces.md.
class WorkAssociations < ApplicationService
  DIRECTIONS = %w[outbound inbound].freeze

  Result = Struct.new(:outbound, :inbound) do
    def empty?
      outbound.empty? && inbound.empty?
    end

    def size
      (outbound.values + inbound.values).sum(&:size)
    end
  end

  def initialize(associations:, search_service:)
    @associations = associations || {}
    @search_service = search_service
    super()
  end

  def call
    return Result.new({}, {}) if noids.empty?

    Result.new(resolve('outbound'), resolve('inbound'))
  end

  private

    def resolve(direction)
      edges = @associations[direction]
      return {} unless edges.is_a?(Hash)

      AtlasRb::Work::ASSOCIATION_TYPES.filter_map do |type|
        docs = Array(edges[type]).filter_map { |noid| documents_by_noid[noid.to_s] }
        [type, docs] if docs.any?
      end.to_h
    end

    def noids
      @noids ||= DIRECTIONS.flat_map do |direction|
        edges = @associations[direction]
        edges.is_a?(Hash) ? edges.values.flatten : []
      end.map(&:to_s).uniq
    end

    # Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`; the same
    # `{!terms}` shape SetResolver#noun_uuids uses.
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
      Blacklight.default_index.search(params: builder)
    end
end
