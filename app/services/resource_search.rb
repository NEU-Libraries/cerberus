# frozen_string_literal: true

# Keyword search over Works, Collections and Communities for the admin finders.
# See docs/discovery.md.
#
# Gated: the search runs through the normal {SearchBuilder} chain, so an admin
# sees non-public resources. Only ever invoke it from an admin-gated controller.
class ResourceSearch < ApplicationService
  DEFAULT_PER_PAGE = 25

  def initialize(scope:, query: nil, types: %w[Collection Community], # rubocop:disable Metrics/ParameterLists
                 exclude_node_uuid: nil, exclude_subtree_noid: nil, within_fq: nil)
    @scope = scope
    @query = query
    @types = Array(types)
    @exclude_node_uuid = exclude_node_uuid
    @exclude_subtree_noid = exclude_subtree_noid
    @within_fq = within_fq
    super()
  end

  def call
    return empty_response if @query.blank?

    builder = SearchBuilder.new(@scope)
                           .with(q: @query.to_s, per_page: DEFAULT_PER_PAGE)
                           .with_filters(*filters)
    Blacklight.default_index.search(params: builder)
  end

  def filters
    fq = ["internal_resource_tesim:(#{@types.join(' OR ')})", '-tombstoned_bsi:true']
    fq << "-id:\"#{@exclude_node_uuid}\"" if @exclude_node_uuid.present?
    fq << "-ancestor_ids_ssim:\"#{@exclude_subtree_noid}\"" if @exclude_subtree_noid.present?
    fq << @within_fq if @within_fq.present?
    fq
  end

  private

    def empty_response
      Blacklight::Solr::Response.new({}, {})
    end
end
