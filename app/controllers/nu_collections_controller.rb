class NuCollectionsController < SetsController
  include Drs::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]

  before_filter :can_read?, only: [:show]
  before_filter :can_edit?, only: [:edit, :update, :destroy]

  before_filter :can_edit_parent?, only: [:new, :create]
  before_filter :parent_is_personal_folder?, only: [:new, :create]

  rescue_from Exceptions::NoParentFoundError, with: :index_redirect
  rescue_from Exceptions::SearchResultTypeError, with: :index_redirect_with_bad_search

  rescue_from ActiveFedora::ObjectNotFoundError do 
    @obj_type = "Collection" 
    render "error/object_404" 
  end

  def new
    @page_title = "New Collection"
    @set = NuCollection.new(parent: params[:parent])
    render :template => 'shared/sets/new'
  end

  def create
    @set = NuCollection.new(params[:set].merge(pid: mint_unique_pid))

    parent = ActiveFedora::Base.find(params[:set][:parent], cast: true)

    # Assign personal folder specific info if parent folder is a 
    # personal folder. 
    if parent.is_personal_folder? 
      @set.user_parent = parent.user_parent 

      if parent.personal_folder_type == 'user root' 
        @set.personal_folder_type = 'miscellany' 
      else
        @set.personal_folder_type = parent.personal_folder_type 
      end
    end

    # Process Thumbnail
    if params[:thumbnail]
      InlineThumbnailCreator.new(@set, params[:thumbnail], "thumbnail").create_thumbnail
    end

    @set.depositor = current_user.nuid 
    @set.identifier = @set.pid

    if @set.save!
      flash[:notice] = "Collection created successfully."
      redirect_to nu_collection_path(id: @set.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_nu_collection_path(parent: params[:parent]) and return 
    end
  end

  def show  
    @set = NuCollection.find(params[:id])
    @page_title = @set.title
    render :template => 'shared/sets/show' 
  end

  def edit
    @set = NuCollection.find(params[:id])
    @page_title = "Edit #{@set.title}" 
    render :template => 'shared/sets/edit' 
  end

  def update
    @set = NuCollection.find(params[:id]) 

    # Update the thumbnail 
    if params[:thumbnail] 
      InlineThumbnailCreator.new(@set, params[:thumbnail], "thumbnail").create_thumbnail
    end

    if @set.update_attributes(params[:set]) 
      redirect_to(@set, notice: "Collection #{@set.title} was updated successfully." ) 
    else
      redirect_to(@set, notice: "Collection #{@set.title} failed to update.")
    end
  end

  def destroy 
    @title = NuCollection.find(params[:id]).title 

    if NuCollection.find(params[:id]).recursive_delete 
      redirect_to(communities_path, notice: "#{@title} and its descendents destroyed") 
    else
      redirect_to(communities_path, notice: "Something went wrong. #{@title} persists") 
    end
  end

  protected 

    def index_redirect
      flash[:error] = "Collections cannot be created without a parent" 
      redirect_to communities_path and return 
    end

    def index_redirect_with_bad_id 
      flash[:error] = "The id you specified does not seem to exist in Fedora." 
      redirect_to communities_path and return 
    end

    def index_redirect_with_bad_search(exception)
      flash[:error] = exception.message
      redirect_to communities_path and return
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
        redirect_to nu_collections_path and return 
      end
    end
end
