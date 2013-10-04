class DepartmentsController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects 
  
  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]
  before_filter :can_read?, only: [:show, :employees, :research_publications, :other_publications,
                                   :presentations, :data_sets, :learning_objects]
  before_filter :can_edit?, only: [:edit, :update, :destroy]
  before_filter :can_edit_parent?, only: [:new, :create]

  rescue_from NoParentFoundError, with: :index_redirect
  rescue_from IdNotFoundError, with: :index_redirect_with_bad_id  

  def index
  end

  def show
    @set = Department.find(params[:id])
    render :template => 'shared/sets/show'    
  end

  def new
    @department = Department.new(parent: params[:parent])
  end

  def create
    @set = Department.new(params[:set].merge(pid: mint_unique_pid))

    @set.identifier = @set.pid

    if @set.save!
      flash[:info] = "Department created successfully."
      redirect_to department_path(id: @set.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_department_path(parent: params[:parent]) and return 
    end
  end  

  def edit
    @department = Department.find(params[:id])
  end

  def update
    @set = Department.find(params[:id])  
    if @set.update_attributes(params[:set]) 
      redirect_to(@set, notice: "Department #{@set.title} was updated successfully." ) 
    else
      redirect_to(@set, notice: "Department #{@set.title} failed to update.")
    end    
  end

  def employees 
    @dept = Department.find(params[:id]) 
  end

  def research_publications
    @dept = Department.find(params[:id])
  end

  def other_publications
    @dept = Department.find(params[:id]) 
  end

  def presentations
    @dept = Department.find(params[:id])
  end

  def data_sets
    @dept = Department.find(params[:id]) 
  end

  def learning_objects 
    @dept = Department.find(params[:id])
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