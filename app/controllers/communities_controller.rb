# frozen_string_literal: true

class CommunitiesController < CatalogController
  def show
    @community = AtlasRb::Community.find(params[:id])
    @response = find_many(AtlasRb::Community.children(params[:id]))
  end

  def new
    @community = OpenStruct.new
  end

  def edit
    # TODO: need to do admin check
    @community = AtlasRb::Community.find(params[:id])
  end

  def create
    permitted = params.require(:community).permit(:title, :description).to_h

    c = AtlasRb::Community.create(params[:parent_id])
    AtlasRb::Community.metadata(c['id'], permitted)
    redirect_to community_path(c['id'])
  end

  def update
    permitted = params.require(:community).permit(:title, :description).to_h
    AtlasRb::Community.metadata(params[:id], permitted)
    redirect_to community_path(params[:id])
  end
end
