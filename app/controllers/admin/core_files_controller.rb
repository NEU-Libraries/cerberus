require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class Admin::CoreFilesController < AdminController

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
    @page_title = "Administer Core Files"
  end

  # routed to /admin/files/:id
  def show
    @core_file = ActiveFedora::Base.find(params[:id], cast: true)
    @mods = Sanitize.clean(Kramdown::Document.new(render_mods_display(CoreFile.find(@core_file.pid))).to_html, :elements => ['sup', 'sub', 'dt', 'dd', 'br', 'a']).html_safe
    @thumbs = @core_file.thumbnail_list
    @page_title = @core_file.title
  end

  def revive
    @core_file = CoreFile.find(params[:id])
    pid = @core_file.pid
    title = @core_file.title
    parent = Collection.find(@core_file.properties.parent_id[0])
    @core_file.revive
    if @core_file.revive
      redirect_to admin_files_path, notice: "The file #{ActionController::Base.helpers.link_to title, core_file_path(pid)} has been revived".html_safe
    else
      redirect_to admin_files_path, alert: "The core file '#{title}' could not be revived because the parent '#{ActionController::Base.helpers.link_to parent.title, admin_collections_path(parent.pid)}' is tombstoned.".html_safe
    end
  end

  def destroy
    @core_file = CoreFile.find(params[:id])
    pid = @core_file.pid

    if @core_file.destroy
      redirect_to admin_files_path, notice: "The file #{pid} has been deleted"
    else
      redirect_to admin_files_path, notice: "Something went wrong"
    end
  end

  def get_core_files(type)
    filter_name = "limit_to_#{type}"
    @type = type.to_sym
    self.solr_search_params_logic += [filter_name.to_sym]
    (@response, @core_files) = get_search_results
    @count_for_files = @response.response['numFound']
    respond_to do |format|
      format.js {
        if @response.response['numFound'] == 0
          render js:"$('##{type} .core_files').replaceWith(\"<div class='core_files'>There are currently 0 #{type} files.</div>\");"
        else
          render "#{type.to_sym}"
        end
      }
    end
    self.solr_search_params_logic.delete(filter_name.to_sym)
  end

  def get_tombstoned
    get_core_files("tombstoned")
  end

  def get_in_progress
    get_core_files("in_progress")
  end

  def get_incomplete
    get_core_files("incomplete")
  end

  private

    def limit_to_tombstoned(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "tombstoned_ssi:\"true\" AND active_fedora_model_ssi:\"CoreFile\""
    end
    def limit_to_in_progress(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "in_progress_tesim:\"true\""
    end
    def limit_to_incomplete(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "incomplete_tesim:\"true\""
    end

end
