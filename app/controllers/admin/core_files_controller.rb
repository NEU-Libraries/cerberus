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

  before_filter :authenticate_user!
  before_filter :verify_admin
  #before_filter :load_employee, except: [:index, :update, :filter_list]

  def index
    self.solr_search_params_logic += [:limit_to_tombstone]
    (@response, @tombstoned) = get_search_results
    @count_for_tombstone = @tombstoned.length
    self.solr_search_params_logic.delete(:limit_to_tombstone)

    self.solr_search_params_logic += [:limit_to_in_progress]
    (@response, @in_progress) = get_search_results
    @count_for_in_progress = @in_progress.length
    self.solr_search_params_logic.delete(:limit_to_in_progress)

    self.solr_search_params_logic += [:limit_to_incomplete]
    (@response, @incomplete) = get_search_results
    @count_for_incomplete = @incomplete.length
    self.solr_search_params_logic.delete(:limit_to_incomplete)


    @page_title = "Administer Core Files"
  end

  def revive
    @core_file = CoreFile.find(params[:id])
    pid = @core_file.pid
    title = @core_file.title
    @core_file.revive
    redirect_to admin_files_path, notice: "Core File #{ActionController::Base.helpers.link_to title, core_file_path(pid)} has been revived".html_safe
  end

  def destroy
    @core_file = CoreFile.find(params[:id])
    pid = @core_file.pid

    if @core_file.pid
      redirect_to admin_files_path, notice: "Core File #{pid} removed"
    else
      redirect_to admin_files_path, notice: "Something went wrong"
    end
  end


  private

    def limit_to_tombstone(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "tombstoned_ssi:\"true\""
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
