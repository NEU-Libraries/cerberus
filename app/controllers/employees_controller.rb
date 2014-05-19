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

  def list_files
    # @employee = Employee.find(params[:id])
    @employee = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
    @files = @employee.user_root_collection.all_descendent_files
  end

  def personal_graph
    @employee = current_users_employee_id
    @page_title = "My DRS"
  end

  def attach_employee
  end

  private

    def find_employees_files(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("parent_id", :stored_searchable)}:\"#{@set_id}\""
    end

    def current_users_employee_id
      begin
        return Employee.find_by_nuid(current_user.nuid)
      rescue ActiveFedora::ObjectNotFoundError => exception
        flash[:error] = "You have not been granted personal directories"
        ExceptionNotifier.notify_exception(exception)
        redirect_to root_path
      end
    end
end
