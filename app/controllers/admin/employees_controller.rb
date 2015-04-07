require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class Admin::EmployeesController < AdminController

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  before_filter :authenticate_user!
  before_filter :verify_admin
  before_filter :load_employee, except: [:index, :update, :filter_list]

  def index
    self.solr_search_params_logic += [:limit_to_employees]
    (@response, @employees) = get_search_results
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

  def filter_list
    params[:q] = params[:search]
    self.solr_search_params_logic += [:title_search]
    self.solr_search_params_logic += [:limit_to_employees]
    (@response, @employees) = get_search_results
    respond_to do |format|
      format.js {
        if @response.response['numFound'] == 0
          render js:"$('.employees').replaceWith(\"<div class='employees'>No results found.</div>\");"
        else
          render :filter_list
        end
      }
    end
  end

  private

    def load_employee
      @employee = Employee.find(params[:id])
    end

    def limit_to_employees(solr_parameters, user_parameters)
      employee_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Employee"
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "has_model_ssim:\"#{employee_model}\""
    end
    def title_search(solr_parameters, user_parameters)
      solr_parameters[:qf] = "title_tesim"
    end
end
