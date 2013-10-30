class Admin::EmployeesController < ApplicationController

  before_filter :authenticate_user! 
  before_filter :verify_admin

  def index 
    @employees = Employee.all
  end

  def show 

  end

  def edit 

  end

  def update 

  end

  def destroy 

  end

  private 

    def verify_admin 
      redirect_to root_path unless current_user.admin? 
    end
end