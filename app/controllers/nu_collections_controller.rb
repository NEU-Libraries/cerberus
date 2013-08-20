class NuCollectionsController < ApplicationController
  before_filter :authenticate_user!, only: [:new, :edit, :create ] 

  def index
  end

  def new
    @nu_collection = NuCollection.new    
  end

  def create
    @nu_collection = NuCollection.new(params[:nu_collection])

    #Assign misc. data
    @nu_collection.depositor = current_user.nuid 
    @nu_collection.rightsMetadata.permissions({person: current_user.nuid}, 'edit')        

    if @nu_collection.save! # Have to hit Fedora before we have a valid identifier assigned.
      @nu_collection.identifier = @nu_collection.pid
      @nu_collection.save! # Save a second time to get the identifier set.  Very far from ideal. 

      dumb_lookup = NuCollection.find(@nu_collection.pid)
      if ! dumb_lookup.parent
        @nu_collection.destroy 
        raise "Created a collection with no parent.  Rolling back" 
      end

      redirect_to(@nu_collection, notice: "Collection #{@nu_collection.title} was created successfully.") 
    else
      redirect_to(new_nu_collection_url, notice: "Something went wrong") 
    end 
  end

  def index
    @all_collections = NuCollection.find_all_viewable(current_user) 
  end

  def show  
    @nu_collection = NuCollection.find(params[:id]) 
  end

  def edit
    @nu_collection = NuCollection.find(params[:id]) 
  end
end
