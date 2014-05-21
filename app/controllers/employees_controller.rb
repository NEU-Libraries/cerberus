require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class EmployeesController < ApplicationController

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

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
    @employee = Employee.find(params[:id])
    @nuid = @employee.nuid

    @employee = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)

    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:find_employees_files]

    (@response, @document_list) = get_search_results
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
      solr_parameters[:fq] << "#{Solrizer.solr_name("depositor", :stored_searchable)}:\"#{@nuid}\""
    end

    def exclude_unwanted_models(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:NuCoreFile\""
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
