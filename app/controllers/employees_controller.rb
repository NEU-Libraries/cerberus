class EmployeesController < ApplicationController 
  before_filter :authenticate_user!

  def show
    @employee = current_users_employee_id 
  end

  private

    def current_users_employee_id 
      begin 
        return Employee.find_by_nuid(current_user.nuid) 
      rescue ActiveFedora::ObjectNotFoundError 
        flash[:error] = "You have not been granted personal directories" 
        redirect_to root_path
      end
    end
end