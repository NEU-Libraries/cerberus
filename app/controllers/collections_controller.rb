# frozen_string_literal: true

class CollectionsController < CatalogController
  def show
    @collection = Collection.find(params[:id])
    @response = find_many(@collection.filtered_children)
  end

  def new
    @resource = CollectionChangeSet.new(Collection.new)
  end
end
