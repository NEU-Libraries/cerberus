class CommunitiesController < SetsController
  include Drs::ControllerHelpers::EditableObjects
  
  before_filter :can_read?, except: [:index] 

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
    @page_title = @set.title
    render :template => 'shared/sets/show'    
  end

  def employees 
    @dept = Community.find(params[:id]) 
    @page_title = "#{@dept.title} Staff"
  end

  def research_publications
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Research Papers" 
  end

  def other_publications
    @dept = Community.find(params[:id]) 
    @page_title = "#{@dept.title} Papers"
  end

  def presentations
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Presentations" 
  end

  def data_sets
    @dept = Community.find(params[:id]) 
    @page_title = "#{@dept.title} Data Sets" 
  end

  def learning_objects 
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Learning Objects"
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