# frozen_string_literal: true

class CollectionsController < CatalogController
  def show
    # @collection = Collection.find(params[:id])
    # @response = find_many(@collection.filtered_children)

    @collection = AtlasRb::Collection.find(params[:id])
    @response = find_many(AtlasRb::Collection.children(params[:id]))
  end

  def new
    # @resource = CollectionChangeSet.new(Collection.new)
  end

  def edit
    # TODO: need to do permissions check
    # @resource = CollectionChangeSet.new(Collection.find(params[:id]).decorate)
  end
end
