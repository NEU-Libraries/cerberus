require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class CollectionsController < ApplicationController
  include HandleHelper
  include Cerberus::TempFileStorage
  include Cerberus::ControllerHelpers::EditableObjects
  include Cerberus::ControllerHelpers::PermissionsCheck
  include UrlHelper

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  helper_method :sort_value

  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]

  # We can do better by using SOLR check instead of Fedora
  before_filter :can_read?, only: [:show]
  # before_filter :enforce_show_permissions, :only=>:show
  self.solr_search_params_logic += [:add_access_controls_to_solr_params]

  before_filter :can_edit?, only: [:edit, :update]
  before_filter :is_depositor?, only: [:destroy]
  before_filter :can_edit_parent?, only: [:new, :create]
  before_filter :valid_form_permissions?, only: [:update]

  rescue_from Exceptions::NoParentFoundError, with: :index_redirect
  rescue_from Exceptions::SearchResultTypeError, with: :index_redirect_with_bad_search

  rescue_from Blacklight::Exceptions::InvalidSolrID, ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Collection"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end

  rescue_from Hydra::AccessDenied, CanCan::AccessDenied do |exception|
    flash[:error] = exception.message

    if !current_user.nil?
      email_handled_exception(exception)
    end

    render_403 and return
  end

  def facet
    @set = fetch_solr_document

    if !params[:q].nil?
      # Fixes #667 - we remove single characters. They're a pretty terrible idea with a strict AND
      params[:q].gsub!(/(^| ).( |$)/, ' ')
      self.solr_search_params_logic += [:limit_to_scope]
    else
      self.solr_search_params_logic += [:show_children_only]
    end

    @pagination = get_facet_pagination(params[:solr_field], params)

    respond_to do |format|
      # Draw the facet selector for users who have javascript disabled:
      format.html { render :template => 'catalog/facet' }

      # Draw the partial for the "more" facet modal window:
      format.js { render :template => 'catalog/facet', :layout => false }
    end
  end

  def new
    @page_title = "New Collection"
    @set = Collection.new(parent: params[:parent])
    # Set public default permissions if parent is public
    if @set.parent.mass_permissions == 'public'
      @set.mass_permissions = 'public'
    end
    render :template => 'shared/sets/new'
  end

  def create
    @set = Collection.new(params[:set].merge(pid: mint_unique_pid))

    parent = ActiveFedora::Base.find(params[:set][:parent], cast: true)

    # Assign personal collection specific info if parent collection is a
    # smart collection.
    if parent.is_smart_collection?

      if !(parent.smart_collection_type == "Theses and Dissertations")
        @set.user_parent = parent.user_parent.nuid
      end

      if parent.smart_collection_type == 'User Root'
        @set.smart_collection_type = 'miscellany'
      else
        @set.smart_collection_type = parent.smart_collection_type
      end

    end

    # Process Thumbnail
    if params[:thumbnail]
      file = params[:thumbnail]
      new_path = move_file_to_tmp(file)
      Cerberus::Application::Queue.push(SetThumbnailCreationJob.new(@set.pid, new_path))
    end

    @set.depositor = current_user.nuid
    # @set.identifier = @set.pid

    # Create a handle
    @set.identifier = make_handle("#{Rails.configuration.persistent_collection_path}#{@set.pid}")

    # Add drs staff to permissions for #608
    @set.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

    begin
      @set.save!
      UploadAlert.create_from_collection(@set, :create, current_user)
      flash[:notice] = "Collection created successfully."
      redirect_to collection_path(id: @set.pid) and return
    rescue => exception
      logger.error "CollectionsController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      flash.now[:error] = "Something went wrong"
      email_handled_exception(exception)
      redirect_to new_collection_path(parent: params[:parent]) and return
    end
  end

  def show
    @set = fetch_solr_document

    @page_title = @set.title
    if !@set.description.blank?
      @pretty_description = convert_urls(@set.description)
    end

    if !@set.smart_collection_type.nil? && @set.smart_collection_type == 'User Root'
      #redirect to employee view
      return redirect_to employee_path((Employee.find_by_nuid(@set.depositor)).pid)
    end

    if !params[:q].nil?
      self.solr_search_params_logic += [:limit_to_scope]

      if params[:sort].blank?
        # Default sort relevance
        params[:sort] = "score desc, #{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc"
      end
    else
      self.solr_search_params_logic += [:disable_highlighting]
      self.solr_search_params_logic += [:show_children_only]
    end

    (@response, @document_list) = get_search_results

    respond_to do |format|
      format.html { render 'shared/sets/show', locals: {pretty_description: @pretty_description} }
    end
  end

  def edit
    @set = Collection.find(params[:id])
    @page_title = "Edit #{@set.title}"
    render :template => 'shared/sets/edit'
  end

  def update
    @set = Collection.find(params[:id])

    # Update the thumbnail
    if params[:thumbnail]
      file = params[:thumbnail]
      new_path = move_file_to_tmp(file)
      Cerberus::Application::Queue.push(SetThumbnailCreationJob.new(@set.pid, new_path))
    end

    if @set.update_attributes(params[:set])
      UploadAlert.create_from_collection(@set, :update, current_user)
      redirect_to(@set, notice: "Collection #{@set.title} was updated successfully." )
    else
      redirect_to(@set, notice: "Collection #{@set.title} failed to update.")
    end
  end

  def tombstone
    collection = Collection.find(params[:id])
    title = collection.title
    parent = collection.parent
    reason = params[:reason]
    if reason != ""
      collection.tombstone(reason + " " + DateTime.now.strftime("%F"))
    else
      collection.tombstone
    end
    if current_user.admin?
      redirect_to collection_path(id: parent), notice: "The collection '#{title}' has been tombstoned"
    else
      redirect_to collection_path(id: parent), notice: "The collection '#{title}' has been tombstoned"
    end
  end

  def request_tombstone
    collection = Collection.find(params[:id])
    title = collection.title
    user = current_user
    reason = params[:reason]
    TombstoneMailer.tombstone_alert(collection, reason, user).deliver!
    flash[:notice] = "Your request has been received and will be processed soon."
    redirect_to collection and return
  end

  def request_move
    collection = Collection.find(params[:id])
    title = collection.title
    user = current_user
    reason = params[:reason]
    collection_url = params[:collection_url]
    collection_pid = collection_url[/([^\/]+)$/]
    if Collection.exists?(collection_pid)
      MoveMailer.move_alert(collection, reason, collection_url, user).deliver!
      flash[:notice] = "Your request has been received and will be processed soon."
      redirect_to collection and return
    else
      flash[:error] = "That collection does not exist. Please submit a new request and enter a valid collection URL."
      redirect_to collection and return
    end
  end

  def author_list
    @page_title = "#{@set.title} Author List"
    @set = fetch_solr_document
    self.solr_search_params_logic += [:limit_to_scope]

    (@response, @document_list) = get_search_results
    render 'shared/sets/author_list', locals:{sort_value:sort_value}
  end

  protected

    def index_redirect(exception)
      flash[:error] = "Collections cannot be created without a parent"
      email_handled_exception(exception)
      redirect_to root_path and return
    end

    def index_redirect_with_bad_search(exception)
      flash[:error] = exception.message
      email_handled_exception(exception)
      redirect_to root_path and return
    end

    def show_children_only(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("parent_id", :stored_searchable)}:\"#{params[:id]}\""
    end

    def limit_to_scope(solr_parameters, user_parameters)
      descendents = @set.combined_set_descendents

      # Limit query to items that are set descendents
      # or files off set descendents
      query = descendents.map do |set|
        p = set.pid
        set = "id:\"#{p}\" OR is_member_of_ssim:\"info:fedora/#{p}\""
      end

      # Ensure files directly on scoping collection are added in
      # as well
      query << "is_member_of_ssim:\"info:fedora/#{@set.pid}\""

      fq = query.join(" OR ")

      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << fq
    end

    def limit_to_creators(solr_parameters, user_parameters)
      solr_parameters[:fl] ||= []
      solr_parameters[:fl] << "#{Solrizer.solr_name("creator", :stored_searchable)}"
    end

    def disable_highlighting(solr_parameters, user_parameters)
      solr_parameters[:hl] = "false"
    end

    def sort_value
      %w[value hits].include?(params[:sort_val]) ? params[:sort_val] : "value"
    end

end
