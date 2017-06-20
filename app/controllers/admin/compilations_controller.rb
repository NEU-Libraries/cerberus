require 'blacklight/catalog'
require 'blacklight_advanced_search'

class Admin::CompilationsController < AdminController
  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  before_filter :authenticate_user!
  before_filter :verify_admin

  load_resource

  def reindex
    # Launch job with pid list
    doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
    Cerberus::Application::Queue.push(IndexJob.new(doc.all_descendent_pids))
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

  private
  def limit_to_compilations(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:Compilation\""
  end



end
