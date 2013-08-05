class NuCollectionsController < ApplicationController
  def index
  end

  def new
    @nu_collection = NuCollection.new
  end

  def create
    #render text: params[:nu_collection].inspect
    @nu_collection = NuCollection.new
    @nu_collection.nu_title = params[:nu_collection][:nu_title]
    @nu_collection.nu_description = params[:nu_collection][:nu_description]
    @nu_collection.save!
    redirect_to(@nu_collection, :notice => 'Collection was successfully created.')
  end

  def index
    if ! current_user 
      redirect_to('/') 
    else 
      @all_collections = NuCollection.find_all_viewable(current_user) 
    end
  end
end
