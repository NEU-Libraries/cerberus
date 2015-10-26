require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class CommunitiesController < ApplicationController
  include Cerberus::ControllerHelpers::EditableObjects

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller
  include UrlHelper

  # We can do better by using SOLR check instead of Fedora
  before_filter :can_read?, except: [:index, :show]
  before_filter :enforce_show_permissions, :only=>:show
  before_filter :get_set, except: [:index]

  self.solr_search_params_logic += [:add_access_controls_to_solr_params]

  rescue_from Exceptions::NoParentFoundError, with: :index_redirect

  rescue_from Blacklight::Exceptions::InvalidSolrID, ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Community"
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

  def show
    @smart_collections = nil

    @page_title = @set.title
    if !@set.description.blank?
      @pretty_description = convert_urls(@set.description)
    end

    if !params[:q].nil? && !params[:q].blank?
      if params[:id] != Rails.application.config.root_community_id
        self.solr_search_params_logic += [:limit_to_scope]
      end

      if params[:sort].blank?
        # Default sort relevance
        params[:sort] = "score desc, #{Solrizer.solr_name('system_create', :stored_sortable, type: :date)} desc"
      end
    else
      self.solr_search_params_logic += [:disable_highlighting]
      self.solr_search_params_logic += [:show_children_only]
    end

    (@response, @document_list) = get_search_results

    @smart_collections = @set.smart_collections

    respond_to do |format|
      format.html { render 'shared/sets/show', locals: {pretty_description: @pretty_description} }
    end
  end

  def employees
    @page_title = "#{@set.title} #{t('drs.featured_content.employees.name')}"
    safe_get_smart_docs(@set.find_employees)
    render 'smart_collection', locals: { smart_collection: 'employees' }
  end

  def research_publications
    @page_title = "#{@set.title} #{t('drs.featured_content.research.name')}"
    safe_get_smart_docs(@set.research_publications)
    render 'smart_collection', locals: { smart_collection: 'research' }
  end

  def other_publications
    @page_title = "#{@set.title} #{t('drs.featured_content.other.name')}"
    safe_get_smart_docs(@set.other_publications)
    render 'smart_collection', locals: { smart_collection: 'other' }
  end

  def presentations
    @page_title = "#{@set.title} #{t('drs.featured_content.presentations.name')}"
    safe_get_smart_docs(@set.presentations)
    render 'smart_collection', locals: { smart_collection: 'presentations' }
  end

  def datasets
    @page_title = "#{@set.title} #{t('drs.featured_content.datasets.name')}"
    safe_get_smart_docs(@set.datasets)
    render 'smart_collection', locals: { smart_collection: 'datasets' }
  end

  def learning_objects
    @page_title = "#{@set.title} #{t('drs.featured_content.learning.name')}"
    safe_get_smart_docs(@set.learning_objects)
    render 'smart_collection', locals: { smart_collection: 'learning' }
  end

  def monographs
    @page_title = "#{@set.title} #{t('drs.featured_content.monographs.name')}"
    safe_get_smart_docs(@set.monographs)
    render 'smart_collection', locals: { smart_collection: 'monographs' }
  end

  protected

    def get_set
      @set = fetch_solr_document
    end

    def index_redirect(exception)
      flash[:error] = "Communities cannot be created without a parent"
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

    def limit_to_pids(solr_parameters, user_parameters)
      query = @ids.map do |pid|
        "id:\"#{pid}\""
      end

      fq = query.join(" OR ")

      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << fq
    end

    # Ensures that only current_user readable items are returned
    def safe_get_smart_docs(docs)
      if !current_user
        docs.select! { |doc| doc.public? }
      else
        docs.select! { |doc| current_user.can?(:read, doc) }
      end

      @ids = docs.map {|x| x.id}

      # if q or f, change to emulate limit_to_scope
      if !params[:q].nil? || !params[:f].nil?
        self.solr_search_params_logic += [:limit_to_pids]
        (@response, @document_list) = get_search_results
      else
        (@response, @document_list) = get_solr_response_for_field_values('id', @ids, {}).first
      end
    end

    def disable_highlighting(solr_parameters, user_parameters)
      solr_parameters[:hl] = "false"
    end
end
