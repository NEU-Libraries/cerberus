# frozen_string_literal: true

# Resolves the Works contained anywhere beneath a Collection/Community, using the
# two-step reverse-ancestry recipe instead of a recursive subtree walk:
#
#   1. ancestor lookup — find every descendant Collection/Community of the anchor via
#      {MembershipQuery.descendants_fq} (one reverse query against `ancestor_ids_ssim`).
#   2. membership lookup — find the Works that are members of any of those containers
#      (and, with +include_self+, of the anchor itself) via {MembershipQuery.members_fq}.
#
# Both steps run as filter queries through the injected Blacklight search service, so
# gated discovery is applied to each (see SearchBuilder#apply_gated_discovery) and the
# returned object is the same Blacklight::Solr::Response shape that
# CatalogController#find_children returns.
#
# The noid↔uuid seam lives here and only here: step 1 is keyed on the anchor's bare
# *noid* (as stored in `ancestor_ids_ssim`); step 2 is keyed on the descendant
# containers' *uuids* (read off the step-1 result docs' `id`). Callers pass domain
# identifiers, not Solr field values.
#
# NOTE (deferred product decision): both steps are gated by the current user's
# discovery permissions. A future Compilation surface may want step 1 ungated so a
# restricted *intermediate* container does not hide permitted Works beneath it. Left
# gated here; revisit during Compilation modelling.
class DescendantResolver < ApplicationService
  # A Set's flat contents are leaf Works. Intermediate containers are enumerated in
  # step 1 and are not themselves "contents", so they are excluded from the result.
  DEFAULT_TYPE_FILTERS = [
    'internal_resource_tesim:Work',
    '-tombstoned_bsi:true'
  ].freeze

  # @param anchor_noid [String] bare noid of the Collection/Community to resolve.
  # @param search_service [Blacklight::SearchService] supplies the gated search
  #   builder + index (typically the controller's `search_service`).
  # @param anchor_uuid [String, nil] the anchor's own uuid; required only when
  #   +include_self+ is true, to add the anchor's direct members to the result.
  # @param include_self [Boolean] include Works that are direct members of the anchor
  #   itself, not only of its descendants.
  # @param include_linked [Boolean] also match Works linked into the containers via
  #   the DAG overlay (`a_linked_member_of`).
  # @param type_filters [Array<String>] fq fragments narrowing the member result.
  def initialize(anchor_noid:, search_service:, anchor_uuid: nil,
                 include_self: true, include_linked: false,
                 type_filters: DEFAULT_TYPE_FILTERS)
    @anchor_noid = anchor_noid
    @search_service = search_service
    @anchor_uuid = anchor_uuid
    @include_self = include_self
    @include_linked = include_linked
    @type_filters = type_filters
    super()
  end

  # @return [Blacklight::Solr::Response] the resolved Works (gated, paginatable).
  def call
    return empty_response if @anchor_noid.blank?

    container_uuids = descendant_container_uuids
    container_uuids << @anchor_uuid if @include_self && @anchor_uuid.present?
    return empty_response if container_uuids.empty?

    search(
      MembershipQuery.members_fq(container_uuids, include_linked: @include_linked),
      *@type_filters
    )
  end

  private

  # Step 1: reverse-ancestry lookup → uuids of descendant Collections/Communities.
  def descendant_container_uuids
    response = search(
      MembershipQuery.descendants_fq(@anchor_noid),
      'internal_resource_tesim:(Collection OR Community)'
    )
    response.documents.map(&:id)
  end

  def search(*filter_queries)
    builder = @search_service.search_builder.with({}).merge(fq: filter_queries)
    Blacklight.default_index.search(builder)
  end

  def empty_response
    Blacklight::Solr::Response.new({}, {})
  end
end
