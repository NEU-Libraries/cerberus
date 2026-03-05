# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable

  def show
    @collection = AtlasRb::Collection.find(params[:id])
    @response = find_many(AtlasRb::Collection.children(params[:id]))
    breadcrumbs(params[:id])
  end

  def new
    @collection = OpenStruct.new
  end

  def edit
    @collection = AtlasRb::Collection.find(params[:id])
    form_preparation(AtlasRb::Resource.permissions(params[:id]))
  end

  def create
    permitted = params.expect(collection: [:title, :description]).to_h
    c = AtlasRb::Collection.create(params[:parent_id])
    AtlasRb::Collection.metadata(c['id'], permitted)
    redirect_to collection_path(c['id'])
  end

  def update
    AtlasRb::Collection.metadata(params[:id], collection_params)
    redirect_to collection_path(params[:id])
  end

  private

    def collection_params
      resource_params(:collection)
    end
end
