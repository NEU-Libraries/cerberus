class Admin::EmployeesController < AdminController

  before_filter :authenticate_user! 
  before_filter :verify_admin
  before_filter :load_employee, except: [:index, :update] 

  def index 
    @employees = Employee.all
  end

  def edit 

  end

  def update 

    puts "The controller for this action is #{params[:controller]}"
    puts "The referrer for this action is #{request.referrer}" 
    if params[:remove].present?
      @community = params[:remove] 
      @employee = Employee.find(params[:id]) 
      @employee.remove_community(Community.find(params[:remove])) 
      @employee.save!
    elsif request.referrer.include?('admin/communities')
      # Handle the case where an update request is being sent from 
      # the admin/community edit page.  This needs some refactoring.
      @community = params[:id]
      @employee = Employee.find(params[:admin][:employee]) 
      @employee.add_community(Community.find(@community))
      @employee.save!
    else 
      @community = params[:admin][:community]
      @employee = Employee.find(params[:id]) 
      @employee.add_community(Community.find(params[:admin][:community])) 
      @employee.save! 
    end

    respond_to do |format| 
      format.js
    end
  end

  def destroy
    nuid = @employee.nuid

    if @employee.destroy 
      redirect_to admin_employees_path, notice: "Employee #{nuid} removed" 
    else
      redirect_to admin_employees_path, notice: "Something went wrong" 
    end
  end

  private 

    def load_employee
      @employee = Employee.find(params[:id]) 
    end
end