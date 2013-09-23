class EmployeesController < ApplicationController 
  before_filter :authenticate_user!

  def show
  end

  def index
  end

  def new
  end

  def edit
  end

  def update
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