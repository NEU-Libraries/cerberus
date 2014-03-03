require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class NuCollectionsController < SetsController
  include Drs::ControllerHelpers::EditableObjects

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy ]

  # We can do better by using SOLR check instead of Fedora
  #before_filter :can_read?, only: [:show]
  before_filter :enforce_show_permissions, :only=>:show
  before_filter :enforce_viewing_context_for_show_requests, :only=>:show
  self.solr_search_params_logic += [:add_access_controls_to_solr_params]

  before_filter :can_edit?, only: [:edit, :update]
  before_filter :is_depositor?, only: [:destroy]

  before_filter :can_edit_parent?, only: [:new, :create]
  before_filter :parent_is_personal_folder?, only: [:new, :create]

  rescue_from Exceptions::NoParentFoundError, with: :index_redirect
  rescue_from Exceptions::SearchResultTypeError, with: :index_redirect_with_bad_search

  rescue_from ActiveFedora::ObjectNotFoundError do
    @obj_type = "Collection"
    render "error/object_404"
  end

  def new
    @page_title = "New Collection"
    @set = NuCollection.new(parent: params[:parent])
    render :template => 'shared/sets/new'
  end

  def create
    @set = NuCollection.new(params[:set].merge(pid: mint_unique_pid))

    parent = ActiveFedora::Base.find(params[:set][:parent], cast: true)

    # Assign personal folder specific info if parent folder is a
    # personal folder.
    if parent.is_personal_folder?
      @set.user_parent = parent.user_parent.nuid
      if parent.personal_folder_type == 'user root'
        @set.personal_folder_type = 'miscellany'
      else
        @set.personal_folder_type = parent.personal_folder_type
      end
    end

    # Process Thumbnail
    if params[:thumbnail]
      InlineThumbnailCreator.new(@set, params[:thumbnail], "thumbnail").create_thumbnail_and_save
    end

    @set.depositor = current_user.nuid
    @set.identifier = @set.pid

    if @set.save!
      flash[:notice] = "Collection created successfully."
      redirect_to nu_collection_path(id: @set.identifier) and return
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_nu_collection_path(parent: params[:parent]) and return
    end
  end

  def show
    @set_id = params[:id]
    self.solr_search_params_logic += [:find_object]
    (@response, @document_list) = get_search_results
    @set = SolrDocument.new(@response.docs.first)
    @page_title = @set.title

    self.solr_search_params_logic.delete(:find_object)
    self.solr_search_params_logic += [:show_children_only]
    (@response, @document_list) = get_search_results

    render :template => 'shared/sets/show'
  end

  def edit
    @set = NuCollection.find(params[:id])
    @page_title = "Edit #{@set.title}"
    render :template => 'shared/sets/edit'
  end

  def update
    @set = NuCollection.find(params[:id])

    # Update the thumbnail
    if params[:thumbnail]
      InlineThumbnailCreator.new(@set, params[:thumbnail], "thumbnail").create_thumbnail_and_save
    end

    if @set.update_attributes(params[:set])
      redirect_to(@set, notice: "Collection #{@set.title} was updated successfully." )
    else
      redirect_to(@set, notice: "Collection #{@set.title} failed to update.")
    end
  end

  def destroy
    @title = NuCollection.find(params[:id]).title

    if NuCollection.find(params[:id]).recursive_delete
      redirect_to(communities_path, notice: "#{@title} and its descendents destroyed")
    else
      redirect_to(communities_path, notice: "Something went wrong. #{@title} persists")
    end
  end

  protected

    def index_redirect
      flash[:error] = "Collections cannot be created without a parent"
      redirect_to communities_path and return
    end

    def index_redirect_with_bad_id
      flash[:error] = "The id you specified does not seem to exist in Fedora."
      redirect_to communities_path and return
    end

    def index_redirect_with_bad_search(exception)
      flash[:error] = exception.message
      redirect_to communities_path and return
    end

    # In cases where a personal folder is being created,
    # ensure that the parent is also a personal folder.
    def parent_is_personal_folder?
      if params[:is_parent_folder].present?
        parent_id = params[:parent]
      elsif params[:set].present? && params[:set][:user_parent].present?
        parent_id = params[:set][:parent]
      else
        return true
      end

      folder = NuCollection.find(parent_id)
      if !folder.is_personal_folder?
        flash[:error] = "You are attempting to create a personal folder off not a personal folder."
        redirect_to nu_collections_path and return
      end
    end

    def show_children_only(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("parent_id", :stored_searchable)}:\"#{@set_id}\""
    end

    def find_object(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "id:\"#{@set_id}\""
    end
end
