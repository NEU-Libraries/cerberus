class CollectionsController < ApplicationController
  def new
    @set = Collection.new
  end

  def create
    if Collection.new(collection_params).save!
      flash[:notice] = "Collection successfully created."
      redirect_to root_path
    else
      flash.now.error = "Error occured creating collection."
    end
  end

  private
    def collection_params
      params.require(:collection).permit(:title, :description)
    end
end
