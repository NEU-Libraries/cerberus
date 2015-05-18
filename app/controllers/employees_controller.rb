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

  before_filter :authenticate_user!, only: [:personal_graph, :personal_files, :my_communities, :my_loaders]
  before_filter :get_employee, only: [:show, :list_files, :communities, :loaders]

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Faculty Member"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end

  def show
    @system_collections = @employee.user_smart_collections
    @user_collections   = @employee.user_personal_collections

    read_proc = Proc.new do |r|
      current_user ? current_user.can?(:read,r) : r.public?
    end

    @system_collections.keep_if do |x|
      read_proc.call(x)
    end

    @user_collections.keep_if do |x|
      read_proc.call(x)
    end

    if user_examining_self?
      return redirect_to personal_graph_path
    end

    @page_title = "#{@employee.pretty_employee_name}"
  end

  def list_files
    if user_examining_self?
      return redirect_to personal_files_path
    end

    self.solr_search_params_logic += [:add_access_controls_to_solr_params]
    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:find_employees_files]

    (@response, @document_list) = get_search_results

    @page_title = "#{@employee.pretty_employee_name}'s Files"
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

    @page_title = "My Deposits"

    render :template => 'employees/list_files'
  end

  def attach_employee
  end

  def my_communities
    fetch_employee
    @page_title = "My Communities"
    @communities = @employee.communities
    @communities.sort_by!{|c| Community.find(c).title}
    render :template => 'employees/communities'
  end

  def communities
    if user_examining_self?
      return redirect_to my_communities_path
    end
    @communities = @employee.communities
    @communities.sort_by!{|c| Community.find(c).title}
    @page_title = "#{@employee.pretty_employee_name}'s Communities"
  end

  def my_loaders
    fetch_employee
    @page_title = "My Loaders"
    q = ""
    l = current_user.loaders.length
    if l == 0
      render_403 and return
    else
      i = 0
      current_user.loaders.each do |loader|
        i = i + 1
        if i == 1
          q = 'loader_name = "' + loader + '"'
        else
          q = q + ' OR loader_name = "' + loader + '"'
        end
      end
      @loads = Loaders::LoadReport.where(q).paginate(:page => params[:page], :per_page => 10)
      render 'employees/my_loaders'
    end
  end

  def loaders
    if user_examining_self?
      return redirect_to my_loaders_path
    else
      render_403 and return
    end
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
      solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:CoreFile\""
    end
end
