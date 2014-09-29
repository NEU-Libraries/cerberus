class Admin::EmployeesController < AdminController

  before_filter :authenticate_user!
  before_filter :verify_admin
  before_filter :load_employee, except: [:index, :update]

  def index
    employee_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Employee"
    query_result = ActiveFedora::SolrService.query("has_model_ssim:\"#{employee_model}\"")
    @employees = query_result.map { |x| SolrDocument.new(x) }
    @page_title = "Administer Employees"
  end

  def edit
    @page_title = "Administer #{@employee.nuid}"
  end

  def update
    if params[:remove].present?
      @community = params[:remove]
      @employee = Employee.find(params[:id])
      @employee.remove_community(Community.find(params[:remove]))
      @employee.save!
    elsif request.referer.include?('admin/communities')
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
