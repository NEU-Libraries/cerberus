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
    email_handled_exception(exception)
    redirect_to root_path and return
  end

  def index
    redirect_to community_path(id: 'neu:1')
  end

  def facet
    # TODO
  end

  def show
    @smart_collections = nil

    @page_title = @set.title

    if !params[:q].nil?
      if params[:id] != Rails.application.config.root_community_id
        self.solr_search_params_logic += [:limit_to_scope]
      end
    else
      self.solr_search_params_logic += [:show_children_only]
    end

    (@response, @document_list) = get_search_results

    @smart_collections = @set.smart_collections

    render :template => 'shared/sets/show'
  end

  def employees
    @page_title = "#{@set.title} #{t('drs.featured_content.employees.name')}"

    @smart_docs = safe_get_smart_docs(@set.find_employees)
    render 'smart_collection', locals: { smart_collection: 'employees' }
  end

  def research_publications
    @page_title = "#{@set.title} #{t('drs.featured_content.research.name')}"

    @smart_docs = safe_get_smart_docs(@set.research_publications)

    render 'smart_collection', locals: { smart_collection: 'research' }
  end

  def other_publications
    @page_title = "#{@set.title} #{t('drs.featured_content.other.name')}"

    @smart_docs = safe_get_smart_docs(@set.other_publications)
    render 'smart_collection', locals: { smart_collection: 'other' }
  end

  def presentations
    @page_title = "#{@set.title} #{t('drs.featured_content.presentations.name')}"

    @smart_docs = safe_get_smart_docs(@set.presentations)
    render 'smart_collection', locals: { smart_collection: 'presentations' }
  end

  def datasets
    @page_title = "#{@set.title} #{t('drs.featured_content.datasets.name')}"

    @smart_docs = safe_get_smart_docs(@set.datasets)
    render 'smart_collection', locals: { smart_collection: 'datasets' }
  end

  def learning_objects
    @page_title = "#{@set.title} #{t('drs.featured_content.learning.name')}"

    @smart_docs = safe_get_smart_docs(@set.learning_objects)
    render 'smart_collection', locals: { smart_collection: 'learning' }
  end

  protected

    def get_set
      @set = fetch_solr_document
    end

    def index_redirect(exception)
      flash[:error] = "Communities cannot be created without a parent"
      email_handled_exception(exception)
      redirect_to communities_path and return
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

    # Ensures that only current_user readable items are returned
    def safe_get_smart_docs(docs)
      if !current_user
        docs.select! { |doc| doc.public? }
      else
        docs.select! { |doc| current_user.can?(:read, doc) }
      end

      ids = docs.map {|x| x.id}
      @response = get_solr_response_for_field_values('id', ids, {}).first

      return docs
    end
end
