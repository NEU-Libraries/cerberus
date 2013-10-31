class Admin::EmployeesController < ApplicationController

  before_filter :authenticate_user! 
  before_filter :verify_admin
  before_filter :load_employee, except: [:index] 

  def index 
    @employees = Employee.all
  end

  def edit 

  end

  def update 

  end

  def destroy 

  end

  private 

    def load_employee
      @employee = Employee.find(params[:id]) 
    end

    def verify_admin 
      redirect_to root_path unless current_user.admin? 
    end
end