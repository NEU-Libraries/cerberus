# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable

  def show
    @collection = AtlasRb::Collection.find(params[:id])
    @response = find_many(AtlasRb::Collection.children(params[:id]))
  end

  def new
    @collection = OpenStruct.new
  end

  def edit
    @collection = AtlasRb::Collection.find(params[:id])
  end

  def create
    permitted = params.require(:collection).permit(:title, :description).to_h
    c = AtlasRb::Collection.create(params[:parent_id])
    AtlasRb::Collection.metadata(c['id'], permitted)
    redirect_to collection_path(c['id'])
  end

  def update
    # TODO: need to do permissions check
    permitted = params.require(:collection).permit(:title, :description).to_h
    AtlasRb::Collection.metadata(params[:id], permitted)
    redirect_to collection_path(params[:id])
  end
end
