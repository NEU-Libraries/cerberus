# frozen_string_literal: true

class CollectionsController < CatalogController
  def show
    @collection = Collection.find(params[:id])
    @response = find_many(@collection.filtered_children)
  end
end
