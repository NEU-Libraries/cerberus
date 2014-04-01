class EmployeesController < ApplicationController
  before_filter :authenticate_user!, only: [:personal_graph]

  def show
    @employee = Employee.find(params[:id])

    if !current_user.nil?
      if current_user.nuid == @employee.nuid
        return redirect_to personal_graph_path
      end
    end

    @page_title = "#{@employee.nuid}"
  end

  def personal_graph
    @employee = current_users_employee_id
    @page_title = "My DRS"
  end

  def attach_employee
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
