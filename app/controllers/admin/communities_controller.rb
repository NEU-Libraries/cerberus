require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class Admin::CommunitiesController < AdminController
  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  include Cerberus::TempFileStorage

  # Loads @community
  load_resource
  before_filter :not_neu?, only: [:edit, :update, :destroy]

  def index
    self.solr_search_params_logic += [:limit_to_communities]
    (@response, @communities) = get_search_results
    @page_title = "Administer Communities"
  end

  def new
    @page_title = "Create New Community"
  end

  def create
    @community = Community.new(params[:community].merge(pid: mint_unique_pid))
    @community.depositor = current_user.nuid
    @community.identifier = @community.pid

    if get_parent_mass_permissions == 'private' && @community.mass_permissions == 'public'
      flash.now[:error] = "Parent community is set to private, can't have public child."
      render :action => 'new' and return
    end

    # Add drs staff to permissions for #608
    @community.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

    if @community.save!
      update_theses_and_thumbnail
      flash[:notice] = "Community created successfully."
      redirect_to admin_communities_path and return
    else
      flash.now[:error] = "Something went wrong"
      redirect_to admin_communities_path and return
    end
  end

  def edit
    @page_title = "Administer #{@community.title}"
  end

  def update

    if get_parent_mass_permissions == 'private' && @community.mass_permissions == 'public'
      flash.now[:error] = "Parent community is set to private, can't have public child."
      render :action => 'new' and return
    end

    update_theses_and_thumbnail

    if @community.update_attributes(params[:community])
      flash[:notice] =  "Community #{@community.title} was updated successfully."
      redirect_to admin_communities_path
    else
      flash[:notice] = "Community #{@community.title} failed to update."
      redirect_to admin_communities_path
    end
  end

  def destroy
    title = @community.title

    if @community.destroy
      flash[:notice] = "Community #{title} destroyed"
      redirect_to admin_communities_path
    else
      flash[:error] = "Failed to destroy community"
      redirect_to admin_communities_path
    end
  end

  def filter_list
    params[:q] = params[:search]
    self.solr_search_params_logic += [:title_search]
    self.solr_search_params_logic += [:limit_to_communities]
    (@response, @communities) = get_search_results
    respond_to do |format|
      format.js {
        if @response.response['numFound'] == 0
          render js:"$('.communities').replaceWith(\"<div class='communities'>No results found.</div>\");"
        else
          render :filter_list
        end
      }
    end
  end

  private

    def get_parent_mass_permissions
      if params[:community][:parent]
        return Community.find(params[:community][:parent]).mass_permissions
      elsif @community.parent
        return @community.parent.mass_permissions
      else # Need this case to handle community @ neu:1
        return 'public'
      end
    end

    def update_theses_and_thumbnail
      if params[:thumbnail]
        file = params[:thumbnail]
        new_path = move_file_to_tmp(file)
        Cerberus::Application::Queue.push(SetThumbnailCreationJob.new(@community.pid, new_path))
      end

      if params[:theses] && !@community.has_theses?
        etdDesc = I18n.t "drs.etd_description.default"
        Collection.create(title: "Theses and Dissertations",
                            description: "#{etdDesc} #{@community.title}",
                            depositor: current_user.nuid,
                            smart_collection_type: 'Theses and Dissertations',
                            mass_permissions: @community.mass_permissions,
                            parent: @community)
      end
    end

    def limit_to_communities(solr_parameters, user_parameters)
      community_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Community"
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "has_model_ssim:\"#{community_model}\""
    end
    def title_search(solr_parameters, user_parameters)
      solr_parameters[:qf] = "title_tesim"
    end
    def not_neu?
      if @community.pid != 'neu:1'
        return true
      else
        render_403
      end
    end
end
