# frozen_string_literal: true

class CommunitiesController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch

  authorize_resource_writes!

  # Solr membership fields faceted to decide whether a showcase has content
  # (structural children + linked-member edges). See #populated_showcase_ids.
  MEMBERSHIP_FIELDS = [MembershipQuery::STRUCTURAL_FIELD, MembershipQuery::LINKED_FIELD].freeze

  def show
    @community = AtlasRb::Community.find(params[:id])
    return render_gone(@community) if @community.tombstoned

    authorize_show!
    @response = find_children(@community.valkyrie_id, params[:id],
                              exclude_uuids: empty_showcase_uuids(@community.valkyrie_id))
    prepend_faculty_staff_entry(params[:id])
    @can_tombstone = current_ability.can?(:tombstone,
                                          solr_doc_from_permissions(@permissions, klass: 'Community'))
    breadcrumbs(params[:id])
  end

  def tombstone
    AtlasRb::Community.tombstone(params[:id])
    redirect_to root_path, notice: 'Community deleted.'
  end

  def new
    @community = OpenStruct.new
  end

  def edit
    @community = AtlasRb::Community.find(params[:id])
    form_preparation(@permissions)
    load_descriptive!('Community')
    breadcrumbs(params[:id], editing: true)
  end

  def create
    permitted = params.require(:community).permit(:title, :description).to_h

    c = AtlasRb::Community.create(params[:parent_id])
    save_descriptive!('Community', c.id, title: permitted['title'], description: permitted['description'])
    ShowcaseProvisioner.call(community_id: c.id)
    redirect_to community_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Community', resource_key: :community, keywords: false)
  end

  private

    # v1-faithful: only show Featured Collections that have content. Provisioning
    # seeds every community with the full genre showcase set, so without this the
    # browse would be littered with empty showcase rows. We compute the empty
    # showcases up front and exclude them from find_children *at query time* (an
    # fq) — not as a Ruby post-filter on the documents — so the Type facet counts
    # match what's shown (a post-filter leaves Solr's facets counting the hidden
    # rows). Ordinary empty user/workspace Collections are left alone (showing an
    # empty collection one created is intentional); this is scoped to `featured?`
    # showcases, pairing with the Faculty & Staff node so both curated affordances
    # appear only when populated.
    #
    # @param community_uuid [String] the community's valkyrie_id.
    # @return [Array<String>] Solr uniqueKeys of empty featured showcases.
    def empty_showcase_uuids(community_uuid)
      showcase_uuids = featured_showcase_uuids(community_uuid)
      return [] if showcase_uuids.empty?

      showcase_uuids - populated_showcase_ids(showcase_uuids).to_a
    end

    # The Solr uniqueKeys of the community's featured showcase Collections (its
    # structural children flagged featured).
    def featured_showcase_uuids(community_uuid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Collection', 'featured_bsi:true', '-tombstoned_bsi:true',
        MembershipQuery.members_fq([community_uuid], include_linked: false)
      ).merge(rows: 100)
      Blacklight.default_index.search(builder).documents.map(&:id)
    end

    # The subset of +showcase_uuids+ (Solr uniqueKeys) that have >=1 member,
    # structural or linked. One gated, rows-0 facet query over the membership
    # fields restricted to those showcases; the raw facet_counts (value/hits
    # pairs, values in `id-<uuid>` form) are read directly so we don't depend on
    # a configured Blacklight facet. Returns a Set of bare uuids.
    def populated_showcase_ids(showcase_uuids)
      return Set.new if showcase_uuids.empty?

      counts = showcase_member_counts(showcase_uuids)
      MEMBERSHIP_FIELDS.each_with_object(Set.new) do |field, ids|
        each_positive_facet(counts[field]) { |value| ids << value.delete_prefix('id-') }
      end
    end

    def showcase_member_counts(showcase_uuids)
      members = MembershipQuery.members_fq(showcase_uuids, include_linked: true)
      builder = search_service.search_builder.with({}).with_filters(members)
                              .merge(rows: 0, facet: true, 'facet.mincount': 1, 'facet.field': MEMBERSHIP_FIELDS)
      Blacklight.default_index.search(builder).dig('facet_counts', 'facet_fields') || {}
    end

    # Yield each Solr facet value (an `id-<uuid>` string) with a positive count
    # from a flat [value, hits, value, hits, ...] facet_fields array.
    def each_positive_facet(pairs)
      Array(pairs).each_slice(2) { |value, hits| yield value.to_s if hits.to_i.positive? }
    end

    # Surface a synthetic "Faculty & Staff" row as the first entry of a community's
    # browse, rendered through the normal Blacklight pipeline so it matches the
    # list/gallery rows exactly. Only when there are affiliated People to browse,
    # and only on the unfiltered first page (mirrors v1's current_page == 1 && no
    # constraints) so it drops out once the visitor searches-within or facets.
    # The synthetic isn't in Solr, so we also bump the response total by one to
    # keep "Displaying N entries" matching the rows actually shown.
    def prepend_faculty_staff_entry(community_noid)
      return if params[:page].present? && params[:page].to_i > 1
      return if params[:q].present? || params[:f].present?
      return unless affiliated_people_count(community_noid).positive?

      @response.documents.unshift(faculty_staff_stub(community_noid))
      @response.response['numFound'] = @response.total + 1
    end

    # A non-Solr SolrDocument styled as a Person result row (fa-user icon, type
    # pill), titled "Faculty & Staff", carrying its own nav_url to the listing.
    def faculty_staff_stub(community_noid)
      SolrDocument.new(
        'id'                      => "faculty-staff-#{community_noid}",
        'internal_resource_tesim' => ['Person'],
        'title_tsim'              => ['Faculty & Staff'],
        'description_tsim'        => ['Browse faculty and staff by name'],
        'nav_url_ssi'             => community_people_path(community_noid),
        # Public directory affordance — keeps document_status_icons from flagging
        # this synthetic row as private (a lock).
        'read_access_group_ssim'  => ['public']
      )
    end

    # Gated count of Person docs affiliated with this community. Affiliations
    # index as community NOIDs in affiliated_community_ids_ssim.
    def affiliated_people_count(community_noid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Person',
        %(affiliated_community_ids_ssim:"#{community_noid.to_s.gsub(/["\\]/, '')}")
      ).merge(rows: 0)
      Blacklight.default_index.search(builder).total
    end
end
