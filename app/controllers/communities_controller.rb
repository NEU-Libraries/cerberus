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
    AtlasRb::Community.metadata(c.id, permitted)
    redirect_to community_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Community', resource_key: :community, keywords: false)
  end
end
