class CommunitiesController < SetsController
  include Drs::ControllerHelpers::EditableObjects
  
  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]
  before_filter :can_read?, only: [:show, :employees, :research_publications, :other_publications,
                                   :presentations, :data_sets, :learning_objects]
  before_filter :can_edit?, only: [:edit, :update, :destroy]
  before_filter :can_edit_parent?, only: [:new, :create]

  rescue_from Exceptions::NoParentFoundError, with: :index_redirect
  rescue_from ActiveFedora::ObjectNotFoundError, with: :index_redirect_with_bad_id

  rescue_from ActiveFedora::ObjectNotFoundError do 
    @obj_type = "Community" 
    render "error/object_404" 
  end  

  def index
  end

  def show
    @set = Community.find(params[:id])
    render :template => 'shared/sets/show'    
  end

  def new
    @community = Community.new(parent: params[:parent])
  end

  def create
    @set = Community.new(params[:set].merge(pid: mint_unique_pid))

    @set.mass_permissions = 'public'
    @set.rightsMetadata.permissions({person: "#{current_user.nuid}"}, 'edit')

    @set.identifier = @set.pid

    if @set.save!
      flash[:info] = "Community created successfully."
      redirect_to community_path(id: @set.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_community_path(parent: params[:parent]) and return 
    end
  end  

  def edit
    @community = Community.find(params[:id])
  end

  def update
    @set = Community.find(params[:id])  
    if @set.update_attributes(params[:set]) 
      redirect_to(@set, notice: "Community #{@set.title} was updated successfully." ) 
    else
      redirect_to(@set, notice: "Community #{@set.title} failed to update.")
    end    
  end

  def employees 
    @dept = Community.find(params[:id]) 
  end

  def research_publications
    @dept = Community.find(params[:id])
  end

  def other_publications
    @dept = Community.find(params[:id]) 
  end

  def presentations
    @dept = Community.find(params[:id])
  end

  def data_sets
    @dept = Community.find(params[:id]) 
  end

  def learning_objects 
    @dept = Community.find(params[:id])
  end

  protected 

    def index_redirect
      flash[:error] = "Communities cannot be created without a parent" 
      redirect_to communities_path and return 
    end

    def index_redirect_with_bad_id 
      flash[:error] = "The id you specified does not seem to exist in Fedora." 
      redirect_to communities_path and return 
    end  

end