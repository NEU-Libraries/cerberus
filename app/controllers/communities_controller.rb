# frozen_string_literal: true

class CommunitiesController < CatalogController
  include Thumbable
  include Transformable

  before_action :authorize_show!, only: [:show]
  before_action :authorize_edit!, only: [:edit]

  def show
    @community = AtlasRb::Community.find(params[:id])
    @response = find_children(@community.valkyrie_id)
    breadcrumbs(params[:id])
  end

  def new
    @community = OpenStruct.new
  end

  def edit
    @community = AtlasRb::Community.find(params[:id])
    form_preparation(@permissions)
  end

  def create
    permitted = params.require(:community).permit(:title, :description).to_h

    c = AtlasRb::Community.create(params[:parent_id])
    AtlasRb::Community.metadata(c.id, permitted)
    redirect_to community_path(c.id)
  end

  def update
    permitted = params.require(:community).permit(:title, :description).to_h
    add_thumbnail(permitted)
    AtlasRb::Community.metadata(params[:id], permitted)
    redirect_to community_path(params[:id])
  end

  private

    def community_params
      resource_params(:community)
    end
end
