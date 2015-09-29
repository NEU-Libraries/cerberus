require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class Admin::CollectionsController < AdminController

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller
  include ModsDisplay::ControllerExtension

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @page_title = "Administer Collections"
  end

  # routed to /admin/collections/:id
  def show
    @collection = ActiveFedora::Base.find(params[:id], cast: true)
    @thumbs = @collection.thumbnail_list
    if @collection.tombstone_reason
      flash.now[:alert] = "#{@collection.tombstone_reason}"
    end
    @page_title = @collection.title
  end

  def revive
    @collection = Collection.find(params[:id])
    pid = @collection.pid
    title = @collection.title
    parent = Collection.find(@collection.properties.parent_id[0])
    if @collection.revive
      redirect_to admin_collections_path, notice: "The collection #{ActionController::Base.helpers.link_to title, collection_path(pid)} has been revived".html_safe
    else
      redirect_to admin_collections_path, alert: "The collection '#{title}' could not be revived because the parent '#{ActionController::Base.helpers.link_to parent.title, admin_collections_path(parent.pid)}' is tombstoned.".html_safe
    end
  end

  def destroy
    @collection = Collection.find(params[:id])
    pid = @collection.pid

    if @collection.destroy
      redirect_to admin_collections_path, notice: "The collection #{pid} has been deleted"
    else
      redirect_to admin_collections_path, notice: "Something went wrong"
    end
  end

  def get_collections(type)
    filter_name = "limit_to_#{type}"
    @type = type.to_sym
    self.solr_search_params_logic += [filter_name.to_sym]
    (@response, @collections) = get_search_results
    @count_for_collections = @response.response['numFound']
    respond_to do |format|
      format.js {
        if @response.response['numFound'] == 0
          render js:"$('##{type} .collections').replaceWith(\"<div class='collections'>There are currently 0 #{type} collections.</div>\");"
        else
          render "#{type.to_sym}"
        end
      }
    end
    self.solr_search_params_logic.delete(filter_name.to_sym)
  end

  def get_tombstoned
    get_collections("tombstoned")
  end

  private

    def limit_to_tombstoned(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "tombstoned_ssi:\"true\" AND active_fedora_model_ssi:\"Collection\""
    end

end
