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
  include Cerberus::TempFileStorage
  include MimeHelper
  include ChecksumHelper

  before_filter :authenticate_user!, only: [:my_loaders]
  before_filter :get_employee, only: [:show, :list_files, :communities, :loaders]

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Faculty Member"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new, request.fullpath) and return
  end

  def replacement_file
    if !current_user.blank? && (current_user.admin? || current_user.admin_group?)
      # Allow the user to provide a pid
      flash[:info] = "Type in the pid of the binary (PDF, Image, etc.) that you'd like to replace"
      render 'core_files/replacement_file'
    else
      render_403 and return
    end
  end

  def new_replacement_file
    if !current_user.blank? && (current_user.admin? || current_user.admin_group?)
      flash[:alert] = "This process is not reversible. Replaced items are deleted."
      @content_object = ActiveFedora::Base.find(params[:content_object_id], cast: true)
      render 'core_files/new_replacement_file'
    else
      render_403 and return
    end
  end

  def create_replacement_file
    if !current_user.blank? && (current_user.admin? || current_user.admin_group?)
      #
    else
      render_403 and return
    end

    file = params[:file]
    file_name = file.original_filename
    file_path = move_file_to_tmp(file)

    old_content_object = ActiveFedora::Base.find(params[:old_id], cast: true)

    mime_type = extract_mime_type(file_path, file_name)
    extension = extract_extension(mime_type, File.extname(file_name))

    if old_content_object.mime_type != mime_type
      session[:flash_error] = "Mime type must be #{old_content_object.mime_type} not #{mime_type}"
      render :json => { url: my_loaders_path } and return
    end

    if File.extname(old_content_object.original_filename) != ("." + extension)
      session[:flash_error] = "Extension must be #{File.extname(old_content_object.original_filename)} not #{extension}"
      render :json => { url: my_loaders_path } and return
    end

    core_record = CoreFile.find(old_content_object.core_record.pid)
    content_object = old_content_object.class.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
    content_object.save!

    uri = URI("#{ActiveFedora.config.credentials[:url]}/objects/#{content_object.pid}/datastreams/content?controlGroup=M&dsLocation=file://#{file_path}")
    Net::HTTP.start(uri.host, uri.port) do |http|
      http.read_timeout = 60000
      request = Net::HTTP::Post.new uri
      request.basic_auth("#{ActiveFedora.config.credentials[:user]}", "#{ActiveFedora.config.credentials[:password]}")
      res = http.request request # Net::HTTPResponse object
    end

    content_object.reload
    content_object.rightsMetadata.content = old_content_object.rightsMetadata.content
    content_object.core_record = core_record
    content_object.save!

    content_object.original_filename = file_name
    content_object.properties.mime_type = mime_type
    content_object.properties.md5_checksum = new_checksum(file_path)
    content_object.properties.file_size = File.size(file_path).to_s

    if old_content_object.canonical?
      content_object.canonize
    end

    content_object.save!

    old_content_object.destroy
    invalidate_pid(core_record.pid)

    session[:flash_success] = "File was replaced successfully."
    render :json => { url: my_loaders_path } and return
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
      @page_title = "My DRS"
      render :template => 'employees/personal_graph' and return
    else
      @page_title = "#{@employee.pretty_employee_name}"
    end

    respond_to :html
  end

  def list_files
    if user_examining_self?
      fetch_employee

      self.solr_search_params_logic += [:exclude_unwanted_models]
      self.solr_search_params_logic += [:find_employees_files]

      (@response, @document_list) = get_search_results

      @page_title = "My Deposits"

      render :template => 'employees/list_files' and return
    end

    self.solr_search_params_logic += [:add_access_controls_to_solr_params]
    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:find_employees_files]

    (@response, @document_list) = get_search_results

    @page_title = "#{@employee.pretty_employee_name}'s Files"
  end

  def attach_employee
  end

  def communities
    if user_examining_self?
      @page_title = "My Communities"
    else
      @page_title = "#{@employee.pretty_employee_name}'s Communities"
    end

    @communities = @employee.communities
    @communities.sort_by!{|c| Community.find(c).title}
  end

  def generate_token
    if current_user.xml_loader?
      @time = Time.now + 6.hour
      @token = JsonWebToken.encode({user_id: current_user.id, exp: @time.to_i})
    else
      flash[:error] = "You do not have the permissions to peform this action."
      redirect_to root_path and return
    end
  end

  def my_loaders
    if Employee.exists?(current_user.employee_id)
      fetch_employee
    end
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
      @loads = Loaders::LoadReport.where(q).order('created_at DESC').paginate(:page => params[:page], :per_page => 10)
      if session[:flash_error]
        flash[:error] = session[:flash_error]
        session[:flash_error] = nil
      end
      if session[:flash_success]
        flash[:notice] = session[:flash_success]
        session[:flash_success] = nil
      end
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
