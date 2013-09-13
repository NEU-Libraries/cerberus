class NuCollectionsController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects
  
  before_filter :authenticate_user!, only: [:new, :edit, :create ]

   before_filter :can_read?, only: [:show]
   before_filter :can_edit_parent?, only: [:new, :create] 
   before_filter :can_edit?, only: [:edit, :update, :destroy] 

  def index
  end

  def new
    if !NuCollection.exists?(params[:parent])
      flash[:error] = "Collections cannot be created without a parent."
      redirect_to nu_collections_path
    else 
      @nu_collection = NuCollection.new(parent: params[:parent])
    end
  end

  def create
    @nu_collection = NuCollection.new(params[:nu_collection].merge(pid: mint_unique_pid))

    #Assign misc. data
    @nu_collection.depositor = current_user.nuid 
    @nu_collection.identifier = @nu_collection.pid       

    if !current_user_can_edit_parent?(@nu_collection.parent)
      flash.now[:error] = "User #{current_user.email} does not have edit objects on assigned parent." 
      redirect_to(nu_collections_path) and return 
    elsif @nu_collection.save! # Have to hit Fedora before we have a valid identifier assigned.
      @nu_collection.identifier = @nu_collection.pid
      @nu_collection.save! # Save a second time to get the identifier set.  Very far from ideal. 

      dumb_lookup = NuCollection.find(@nu_collection.pid)
      if ! dumb_lookup.parent
        @nu_collection.destroy 
        raise "Created a collection with no parent.  Rolling back" 
      end

      redirect_to(@nu_collection, notice: "Collection #{@nu_collection.title} was created successfully.") 
    else
      redirect_to(new_nu_collection_url(parent: params[:parent]), notice: "Something went wrong") 
    end 
  end

  def show  
    @nu_collection = NuCollection.find(params[:id]) 
  end

  def edit
    @nu_collection = NuCollection.find(params[:id]) 
  end

  def update
    @nu_collection = NuCollection.find(params[:id])  
    if @nu_collection.update_attributes(params[:nu_collection]) 
      redirect_to(@nu_collection, notice: "Collection #{@nu_collection.title} was updated successfully." ) 
    else
      redirect_to(@nu_collection, notice: "Collection #{@nu_collection.title} failed to update.")
    end
  end
end
