# frozen_string_literal: true

# Keyword search over repository resources of given internal_resource types
# (Works, Collections, Communities) for the admin finders — the re-parent flow
# searches containers; the linked-members flow searches Works then Collections.
# Uses the same `Blacklight.default_index.search(builder)` idiom as the other
# Solr service objects, but instead of resolving a subtree it answers "which
# resources of these types match what the admin typed?".
#
# Visibility: this runs through the normal {SearchBuilder} chain, so it inherits
# the (now admin-aware) gated discovery — an admin sees non-public resources,
# which is the whole point of the finders. It is only ever invoked from the
# admin-gated controllers.
#
# The re-parent destination step passes +exclude_node_uuid+ and
# +exclude_subtree_noid+ so the moved node itself and every container beneath it
# are filtered out of the candidates — pre-empting Atlas's `cycle` /
# into-own-descendant rejection before the admin can pick an invalid parent.
class ResourceSearch < ApplicationService
  DEFAULT_PER_PAGE = 25

  # @param scope [#blacklight_config, #current_user] the controller; supplies
  #   the Blacklight config (copied from CatalogController) and the acting user
  #   that gated discovery reads.
  # @param query [String, nil] the admin's keyword query. Blank => no search.
  # @param types [Array<String>] internal_resource types to match
  #   (e.g. %w[Work], %w[Collection Community]).
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
