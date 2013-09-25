class DepartmentsController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects 
  
  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]
  before_filter :can_read?, only: [:show]
  before_filter :can_edit?, only: [:edit, :update, :destroy]
  before_filter :can_edit_parent?, only: [:new, :create]

  rescue_from NoParentFoundError, with: :index_redirect
  rescue_from IdNotFoundError, with: :index_redirect_with_bad_id  

  def index
  end

  def show
    @set = Department.find(params[:id])
    render :template => 'shared/show'    
  end

  def new
    @set = Department.new(parent: params[:parent])
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

  def edit
    @set = Department.find(params[:id])
    render :template => 'shared/edit'
  end

  def update
    @set = Department.find(params[:id])  
    if @set.update_attributes(params[:set]) 
      redirect_to(@set, notice: "Department #{@set.title} was updated successfully." ) 
    else
      redirect_to(@set, notice: "Department #{@set.title} failed to update.")
    end    
  end

  protected 

    def index_redirect
      flash[:error] = "Departments cannot be created without a parent" 
      redirect_to departments_path and return 
    end

    def index_redirect_with_bad_id 
      flash[:error] = "The id you specified does not seem to exist in Fedora." 
      redirect_to departments_path and return 
    end  

end