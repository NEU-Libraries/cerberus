require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class CommunitiesController < SetsController
  include Drs::ControllerHelpers::EditableObjects

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

  def show
    @smart_collections = nil

    @page_title = @set.title

    self.solr_search_params_logic += [:show_children_only]
    (@response, @document_list) = get_search_results

    @smart_collections = @set.smart_collections

    render :template => 'shared/sets/show'
  end

  def employees
    @page_title = "#{@set.title} #{t('drs.significant.employees.name')}"

    @smart_docs = @set.find_employees
    render 'smart_collection', locals: { smart_collection: 'employees' }
  end

  def research_publications
    @page_title = "#{@set.title} #{t('drs.significant.research.name')}"

    @smart_docs = @set.research_publications
    render 'smart_collection', locals: { smart_collection: 'research' }
  end

  def other_publications
    @page_title = "#{@set.title} #{t('drs.significant.other.name')}"

    @smart_docs = @set.other_publications
    render 'smart_collection', locals: { smart_collection: 'other' }
  end

  def presentations
    @page_title = "#{@set.title} #{t('drs.significant.presentations.name')}"

    @smart_docs = @set.presentations
    render 'smart_collection', locals: { smart_collection: 'presentations' }
  end

  def datasets
    @page_title = "#{@set.title} #{t('drs.significant.datasets.name')}"

    @smart_docs = @set.datasets
    render 'smart_collection', locals: { smart_collection: 'datasets' }
  end

  def learning_objects
    @page_title = "#{@set.title} #{t('drs.significant.learning.name')}"

    @smart_docs = @set.learning_objects
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
end
