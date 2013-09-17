class NuCollectionsController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]

  before_filter :can_read?, only: [:show]
  before_filter :can_edit?, only: [:edit, :update, :destroy]

  before_filter :can_edit_parent?, only: [:new, :create]
  rescue_from NoParentFoundError, with: :index_redirect
  rescue_from IdNotFoundError, with: :index_redirect_with_bad_id


  def index
  end

  def new
    @nu_collection = NuCollection.new(parent: params[:parent])
  end

  def create
    @nu_collection = NuCollection.new(params[:nu_collection].merge(pid: mint_unique_pid))

    #Assign misc. data
    @nu_collection.depositor = current_user.nuid 
    @nu_collection.identifier = @nu_collection.pid

    if @nu_collection.save!
      flash[:info] = "Collection created successfully."
      redirect_to nu_collection_path(id: @nu_collection.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_nu_collection_path(parent: params[:parent]) and return 
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

  protected 

    def index_redirect
      flash[:error] = "Collections cannot be created without a parent" 
      redirect_to nu_collections_path and return 
    end

    def index_redirect_with_bad_id 
      flash[:error] = "The id you specified does not seem to exist in Fedora." 
      redirect_to nu_collections_path and return 
    end
end
