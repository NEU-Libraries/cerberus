# frozen_string_literal: true

class CollectionsController < CatalogController
  def show
    @collection = Collection.find(params[:id])
    @response = find_many(@collection.filtered_children)
  end

  def new
    @resource = CollectionChangeSet.new(Collection.new)
  end

  def edit
    # TODO: need to do permissions check
    @resource = CollectionChangeSet.new(Collection.find(params[:id]))
  end
end
