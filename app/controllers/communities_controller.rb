class CommunitiesController < SetsController
  include Drs::ControllerHelpers::EditableObjects
  
  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]
  before_filter :can_read?, only: [:show, :employees, :research_publications, :other_publications,
                                   :presentations, :data_sets, :learning_objects]
  before_filter :can_edit?, only: [:edit, :update, :destroy]
  before_filter :can_edit_parent?, only: [:create]
  before_filter :deny_to_visitors, except: [:index, :show]

  rescue_from Exceptions::NoParentFoundError, with: :index_redirect
  rescue_from ActiveFedora::ObjectNotFoundError, with: :index_redirect_with_bad_id

  rescue_from ActiveFedora::ObjectNotFoundError do 
    @obj_type = "Community" 
    render "error/object_404" 
  end  

  def index
    redirect_to community_path(id: 'neu:1')
  end

  def show
    @set = Community.find(params[:id])
    render :template => 'shared/sets/show'    
  end

  def new
    @community = Community.new(parent: params[:parent])
  end

  def create
    @community = Community.new(params[:community].merge(pid: mint_unique_pid))

    @community.mass_permissions = 'public'
    @community.rightsMetadata.permissions({person: "#{current_user.nuid}"}, 'edit')

    @community.identifier = @community.pid

    if @community.save!
      flash[:info] = "Community created successfully."
      redirect_to community_path(id: @community.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_community_path(parent: params[:parent]) and return 
    end
  end  

  def edit
    @community = Community.find(params[:id])
  end

  def update
    @community = Community.find(params[:id])  
    if @community.update_attributes(params[:community]) 
      redirect_to(@community, notice: "Community #{@community.title} was updated successfully." ) 
    else
      redirect_to(@community, notice: "Community #{@community.title} failed to update.")
    end    
  end

  def attach_employee
    #TODO
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