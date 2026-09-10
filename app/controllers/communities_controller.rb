# frozen_string_literal: true

# Community browse, show and edit. See docs/discovery.md.
#
# Every Solr lookup here runs through the gated `search_service.search_builder`,
# so a visitor only ever counts and sees what they may discover. Do not swap in
# a hand-built index query.
class CommunitiesController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch
  include RecordsImpressions
  include ContainerAnalytics
  include ContainerRestrictionRequest

  authorize_resource_writes!(extra_edit: %i[request_restriction])
  after_action :record_view_impression, only: :show

  MEMBERSHIP_FIELDS = [MembershipQuery::STRUCTURAL_FIELD, MembershipQuery::LINKED_FIELD].freeze

  # Scope the inherited Blacklight index to Communities, on :index alone.
  # Without it /communities lists every resource type; applied to :show it would
  # strip the child Collections find_children has to surface.
  def search_service_context
    return super unless action_name == 'index'

    super.merge(resource_type_scope: 'Community')
  end

  def show
    @community = AtlasRb::Community.find(params[:id])
    raise ResourceNotFound if @community.nil?
    return render_gone(@community) if @community.tombstoned

    authorize_show!
    load_children_and_deletability
    prepend_faculty_staff_entry(params[:id])
    assign_show_abilities!(klass: 'Community')
    breadcrumbs(params[:id])
  end

  def tombstone
    perform_tombstone!(AtlasRb::Community.tombstone(params[:id]), type: 'Community')
  end

  def new
    @community = OpenStruct.new
    @create_path = child_create_path('communities')
  end

  def edit
    @community = AtlasRb::Community.find(params[:id])
    # Narrowing a Community is administrator-only, and ResourcePermissions
    # refuses anyone else server-side. See docs/permissions.md.
    @narrowing_allowed = current_user&.admin? || false
    form_preparation(@permissions, resource: @community)
    load_descriptive!('Community')
    load_container_analytics(@community, 'Community')
    breadcrumbs(params[:id], editing: true)
  end

  # Provision showcases only after the community exists and is titled, so a
  # missing title never leaves orphaned showcases behind.
  def create
    c = mint_titled!('Community', :community)
    return redirect_to(new_child_path('community')) if c.nil?

    ShowcaseProvisioner.call(community_id: c.id)
    redirect_to community_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Community', resource_key: :community, keywords: false)
  end

  private

    # The same children #show lists — empty showcases excluded, exactly as the
    # listing excludes them — gated the same way. A caller who may not read the
    # Community must not be able to count its contents. A tombstoned Community
    # has no browsable contents, so it 404s rather than rendering an empty modal.
    def facet_scope_filters
      @community = AtlasRb::Community.find(params[:id])
      raise ResourceNotFound if @community.nil? || @community.tombstoned

      authorize_show!
      showcases = featured_showcase_uuids(@community.valkyrie_id)
      child_membership_filters(@community.valkyrie_id, params[:id],
                               exclude_uuids: empty_showcase_uuids(showcases))
    end

    def load_children_and_deletability
      showcases = featured_showcase_uuids(@community.valkyrie_id)
      @response = find_children(@community.valkyrie_id, params[:id],
                                exclude_uuids: empty_showcase_uuids(showcases))
      @deletable = deletable?(showcases)
    end

    # Exclude the empty showcases at query time, as an fq on find_children, and
    # never as a Ruby post-filter on the returned documents: a post-filter leaves
    # Solr's Type facet counting the rows it hid.
    def empty_showcase_uuids(showcase_uuids)
      return [] if showcase_uuids.empty?

      showcase_uuids - populated_showcase_ids(showcase_uuids).to_a
    end

    # The listing is not the whole test. Atlas refuses a tombstone while any live
    # member remains, and a showcase Collection is a live member even when it is
    # empty and hidden from the listing, so testing @response alone offers Delete
    # on a community that then fails to delete.
    def deletable?(showcase_uuids)
      @response.documents.empty? && showcase_uuids.empty?
    end

    def featured_showcase_uuids(community_uuid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Collection', 'featured_bsi:true', '-tombstoned_bsi:true',
        MembershipQuery.members_fq([community_uuid], include_linked: false)
      ).merge(rows: 100)
      Blacklight.default_index.search(params: builder).documents.map(&:id)
    end

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
      Blacklight.default_index.search(params: builder).dig('facet_counts', 'facet_fields') || {}
    end

    # Solr returns facet_fields as a flat [value, hits, value, hits, ...] array.
    def each_positive_facet(pairs)
      Array(pairs).each_slice(2) { |value, hits| yield value.to_s if hits.to_i.positive? }
    end

    # The synthetic row is not in Solr, so raise the response total by one or
    # "Displaying N entries" undercounts the rows on screen.
    def prepend_faculty_staff_entry(community_noid)
      return if params[:page].present? && params[:page].to_i > 1
      return if params[:q].present? || params[:f].present?
      return unless affiliated_people_count(community_noid).positive?

      @response.documents.unshift(faculty_staff_stub(community_noid))
      @response.response['numFound'] = @response.total + 1
    end

    def faculty_staff_stub(community_noid)
      SolrDocument.new(
        {
          'id'                      => "faculty-staff-#{community_noid}",
          'internal_resource_tesim' => ['Person'],
          'title_tsim'              => ['Faculty & Staff'],
          'description_tsim'        => ['Browse faculty and staff by name'],
          'nav_url_ssi'             => community_people_path(community_noid),
          # Public directory affordance — keeps document_status_icons from flagging
          # this synthetic row as private (a lock).
          'read_access_group_ssim'  => ['public'],
          # Pluralizes the type pill to "People" (SolrDocument#people_browse?).
          'people_browse_bsi'       => true
        },
        # Share the live response: SolrDocument#response defaults to nil, and
        # Blacklight's per-row highlight check reads response['highlighting'],
        # which raises NoMethodError on nil.
        @response
      )
    end

    # Affiliations index as community NOIDs in affiliated_community_ids_ssim.
    def affiliated_people_count(community_noid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Person',
        %(affiliated_community_ids_ssim:"#{community_noid.to_s.gsub(/["\\]/, '')}")
      ).merge(rows: 0)
      Blacklight.default_index.search(params: builder).total
    end
end
