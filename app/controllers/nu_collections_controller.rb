class NuCollectionsController < ApplicationController
  def index
  end

  def new    
  end

  def create
    #render text: params[:nu_collection].inspect
    @nu_collection = NuCollection.new

    #to get a correct pid
    @nu_collection.save!

    @nu_collection.nu_title = params[:nu_collection][:nu_title]
    @nu_collection.nu_description = params[:nu_collection][:nu_description]
    @nu_collection.nu_identifier = @nu_collection.id

    @nu_collection.mods_abstract = params[:nu_collection][:mods_abstract]
    @nu_collection.mods_title = params[:nu_collection][:nu_title]
    @nu_collection.mods_identifier = @nu_collection.id

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

  def show  
    @nu_collection = NuCollection.find(params[:id]) 
  end
end
