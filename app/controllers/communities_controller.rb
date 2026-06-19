# frozen_string_literal: true

class CommunitiesController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch

  before_action :authorize_edit!, only: [:edit]
  before_action :authorize_tombstone!, only: [:tombstone]

  def show
    @community = AtlasRb::Community.find(params[:id])
    return render_gone(@community) if @community.tombstoned

    authorize_show!
    @response = find_children(@community.valkyrie_id, params[:id])
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
    redirect_to community_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Community', resource_key: :community, keywords: false)
  end

  private

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
