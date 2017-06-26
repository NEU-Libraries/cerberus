require 'blacklight/catalog'
require 'blacklight_advanced_search'

class Admin::CompilationsController < AdminController
  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  before_filter :authenticate_user!
  before_filter :verify_admin

  load_resource :except => [:filter_list]

  def reindex
    # Launch job with pid list
    doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
    Cerberus::Application::Queue.push(IndexJob.new(doc.all_descendent_pids))
    flash[:notice] = "#{t('drs.compilations.name').capitalize} reindex has started."
    redirect_to admin_compilations_path and return
  end

  def index
    self.solr_search_params_logic += [:limit_to_compilations]
    (@response, @sets) = get_search_results
    @page_title = "Administer " + t('drs.compilations.name').capitalize + "s"
  end

  def edit
    @page_title = "Manage #{@compilation.title}"
    @set = @compilation
  end

  def update
    @compilation.mass_permissions = params[:mass_permissions]

    if !params[:compilation][:permissions].blank?
      params[:compilation][:permissions].merge!(nuid: current_user.nuid)
    end

    if @compilation.update_attributes(params[:compilation])
      flash[:notice] = "#{t('drs.compilations.name').capitalize} successfully updated."
      redirect_to admin_compilations_path
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} failed to update."
    end
  end

  def destroy
    if @compilation.destroy
      flash[:notice] = "#{t('drs.compilations.name').capitalize} was successfully deleted"
      redirect_to admin_compilations_path
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} #{@compilation.title} was not successfully destroyed"
    end
  end

  def filter_list
    params[:q] = params[:search]
    self.solr_search_params_logic += [:title_search]
    self.solr_search_params_logic += [:limit_to_compilations]
    (@response, @sets) = get_search_results

    respond_to do |format|
      format.js {
        if @response.response['numFound'] == 0
          render js:"$('.sets').replaceWith(\"<div class='sets'>No results found.</div>\");"
        else
          render :filter_list
        end
      }
    end
  end

  private
    def limit_to_compilations(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:Compilation\""
    end

    def title_search(solr_parameters, user_parameters)
      solr_parameters[:qf] = "title_tesim"
    end

end
