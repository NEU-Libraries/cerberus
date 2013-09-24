class NuCollectionsController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]

  before_filter :can_read?, only: [:show]
  before_filter :can_edit?, only: [:edit, :update, :destroy]

  before_filter :can_edit_parent?, only: [:new, :create]
  before_filter :parent_is_personal_folder?, only: [:new, :create] 
  rescue_from NoParentFoundError, with: :index_redirect
  rescue_from IdNotFoundError, with: :index_redirect_with_bad_id


  def index
  end

  def new
    @nu_collection = NuCollection.new(parent: params[:parent])
  end

  def create
    @nu_collection = NuCollection.new(params[:nu_collection].merge(pid: mint_unique_pid))
    @nu_collection.assign_DC_creators(params[:nu_collection][:personal_creators][:creator_first_names],
                                      params[:nu_collection][:personal_creators][:creator_last_names],
                                      params[:nu_collection][:corporate_creators])

    if params[:nu_collection][:user_parent].present?
      @nu_collection.user_parent = Employee.find_by_nuid(params[:nu_collection][:user_parent]) 
      @nu_collection.personal_folder_type = 'miscellany' 
    end

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
      @nu_collection.assign_DC_creators(params[:nu_collection][:personal_creators][:creator_first_names],
                                        params[:nu_collection][:personal_creators][:creator_last_names],
                                        params[:nu_collection][:corporate_creators])
      @nu_collection.save! 
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

    # In cases where a personal folder is being created,
    # ensure that the parent is also a personal folder.
    def parent_is_personal_folder?
      if params[:is_parent_folder].present? 
        parent_id = params[:parent] 
      elsif params[:nu_collection].present? && params[:nu_collection][:user_parent].present? 
        parent_id = params[:nu_collection][:parent]
      else 
        return true 
      end

      folder = NuCollection.find(parent_id) 
      if !folder.is_personal_folder? 
        flash[:error] = "You are attempting to create a personal folder off not a personal folder." 
        redirect_to nu_collections_path and return 
      end
    end
end
