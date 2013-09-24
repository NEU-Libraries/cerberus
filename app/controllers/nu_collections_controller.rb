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
    @set = NuCollection.new(parent: params[:parent])
    render :template => 'shared/new'
  end

  def create
    @set = NuCollection.new(params[:set].merge(pid: mint_unique_pid))

    if params[:set][:user_parent].present?
      @set.user_parent = Employee.find_by_nuid(params[:set][:user_parent]) 
      @set.personal_folder_type = 'miscellany' 
    end

    @set.depositor = current_user.nuid 
    @set.identifier = @set.pid

    if @set.save!
      flash[:info] = "Collection created successfully."
      redirect_to set_path(id: @set.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_set_path(parent: params[:parent]) and return 
    end
  end

  def show  
    @set = NuCollection.find(params[:id])

    render :template => 'shared/show' 
  end

  def edit
    @set = NuCollection.find(params[:id])

    render :template => 'shared/edit' 
  end

  def update
    @set = NuCollection.find(params[:id])  
    if @set.update_attributes(params[:set]) 
      redirect_to(@set, notice: "Collection #{@set.title} was updated successfully." ) 
    else
      redirect_to(@set, notice: "Collection #{@set.title} failed to update.")
    end
  end

  protected 

    def index_redirect
      flash[:error] = "Collections cannot be created without a parent" 
      redirect_to nu_collection_path and return 
    end

    def index_redirect_with_bad_id 
      flash[:error] = "The id you specified does not seem to exist in Fedora." 
      redirect_to nu_collection_path and return 
    end

    # In cases where a personal folder is being created,
    # ensure that the parent is also a personal folder.
    def parent_is_personal_folder?
      if params[:is_parent_folder].present? 
        parent_id = params[:parent] 
      elsif params[:set].present? && params[:set][:user_parent].present? 
        parent_id = params[:set][:parent]
      else 
        return true 
      end

      folder = NuCollection.find(parent_id) 
      if !folder.is_personal_folder? 
        flash[:error] = "You are attempting to create a personal folder off not a personal folder." 
        redirect_to sets_path and return 
      end
    end
end
