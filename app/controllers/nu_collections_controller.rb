class NuCollectionsController < ApplicationController
  def index
  end

  def new
    if !current_user 
      redirect_to('/') 
    else 
      @nu_collection = NuCollection.new    
    end
  end

  def create 
    @nu_collection = NuCollection.new(params[:nu_collection])  

    if @nu_collection.save! #Have to hit Fedora before we have a valid identifier assigned. 
      @nu_collection.identifier = @nu_collection.pid 
      redirect_to(@nu_collection, notice: "Collection #{@nu_collection.title} was created successfully.") 
    else
      redirect_to(new_nu_collection_url, notice: "Something went wrong") 
    end 
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

  def edit
    @nu_collection = NuCollection.find(params[:id]) 
  end
end
