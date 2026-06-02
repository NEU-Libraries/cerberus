# frozen_string_literal: true

# Keyword search over container resources (Collections / Communities) for the
# admin re-parent finder. Mirrors {DescendantResolver}'s
# `Blacklight.default_index.search(builder)` idiom, but instead of resolving a
# subtree it answers "which containers match what the admin typed?".
#
# Visibility: this runs through the normal {SearchBuilder} chain, so it inherits
# the (now admin-aware) gated discovery — an admin sees non-public containers,
# which is the whole point of the finder. It is only ever invoked from the
# admin-gated re-parent controller.
#
# Step 2 (choosing a destination) passes +exclude_node_uuid+ and
# +exclude_subtree_noid+ so the moved node itself and every container beneath it
# are filtered out of the candidate list — pre-empting Atlas's `cycle` /
# into-own-descendant rejection before the admin can pick an invalid parent.
class ContainerSearch < ApplicationService
  DEFAULT_PER_PAGE = 25

  # @param scope [#blacklight_config, #current_user] the controller; supplies
  #   the Blacklight config (copied from CatalogController) and the acting user
  #   that gated discovery reads.
  # @param query [String, nil] the admin's keyword query. Blank => no search.
  # @param types [Array<String>] container types to match (internal_resource).
  # @param exclude_node_uuid [String, nil] Solr `id` (uuid) of the node being
  #   moved — excluded so a node can't be its own parent.
  # @param exclude_subtree_noid [String, nil] noid of the node being moved —
  #   excludes every container whose `ancestor_ids_ssim` contains it (its
  #   descendants).
  def initialize(scope:, query: nil, types: %w[Collection Community],
                 exclude_node_uuid: nil, exclude_subtree_noid: nil)
    @scope = scope
    @query = query
    @types = Array(types)
    @exclude_node_uuid = exclude_node_uuid
    @exclude_subtree_noid = exclude_subtree_noid
    super()
  end

  # @return [Blacklight::Solr::Response] matching container documents, or an
  #   empty response when no query was given (the finder doesn't dump the whole
  #   ~3k-container tree on an empty box).
  def call
    return empty_response if @query.blank?

    builder = SearchBuilder.new(@scope)
                           .with(q: @query.to_s, per_page: DEFAULT_PER_PAGE)
                           .with_filters(*filters)
    Blacklight.default_index.search(builder)
  end

  # The fq fragments this search applies. Pure — unit-tested directly.
  # @return [Array<String>]
  def filters
    fq = ["internal_resource_tesim:(#{@types.join(' OR ')})", '-tombstoned_bsi:true']
    fq << "-id:\"#{@exclude_node_uuid}\"" if @exclude_node_uuid.present?
    fq << "-ancestor_ids_ssim:\"#{@exclude_subtree_noid}\"" if @exclude_subtree_noid.present?
    fq
  end

  private

    def empty_response
      Blacklight::Solr::Response.new({}, {})
    end
end
