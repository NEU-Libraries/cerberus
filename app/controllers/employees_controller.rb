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

  before_filter :authenticate_user!, only: [:personal_graph, :personal_files]
  before_filter :get_employee, only: [:show, :list_files]

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Faculty Member"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end

  def show
    if user_examining_self?
      return redirect_to personal_graph_path
    end

    @page_title = "#{@employee.employee_name}"
  end

  def list_files
    if user_examining_self?
      return redirect_to personal_files_path
    end

    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:find_employees_files]

    (@response, @document_list) = get_search_results

    @page_title = "#{@employee.employee_name}'s Files"
  end

  def personal_graph
    fetch_employee
    @page_title = "My DRS"
  end

  def personal_files
    fetch_employee

    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:find_employees_files]

    (@response, @document_list) = get_search_results

    @page_title = "My Files"

    render :template => 'employees/list_files'
  end

  def attach_employee
  end

  private

    def user_examining_self?
      return !current_user.nil? && (current_user.nuid == @employee.nuid)
    end

    def get_employee
      @employee = fetch_solr_document
    end

    def fetch_employee(retries=0)
      begin
        e_pid = current_user.employee_pid
      rescue Exceptions::NoSuchNuidError
        if retries < 3
          sleep 1
          fetch_employee(retries + 1)
        else
          raise Exceptions::NoSuchNuidError.new(current_user.nuid)
        end
      end

      @employee = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{current_user.employee_pid}\"").first)
    end

    def find_employees_files(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("depositor", :stored_searchable)}:\"#{@employee.nuid}\""
    end

    def exclude_unwanted_models(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:NuCoreFile\""
    end
end
