class CompilationsController < ApplicationController
  include Cerberus::ControllerHelpers::EditableObjects
  include Cerberus::ControllerHelpers::PermissionsCheck
  include ApplicationHelper
  include UrlHelper

  # Here be solr access boilerplate
  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)
  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  before_filter :authenticate_user!, except: [:show, :show_download, :download, :ping_download, :get_total_count, :total_count]

  before_filter :can_edit?, only: [:edit, :update, :destroy, :add_entry, :delete_entry, :add_multiple_entries, :delete_multiple_entries]
  before_filter :can_read?, only: [:show, :show_download, :download]
  self.solr_search_params_logic += [:add_access_controls_to_solr_params]

  load_resource
  before_filter :valid_form_permissions?, only: [:update]

  def index
    @page_title = "My " + t('drs.compilations.name').capitalize + "s"
    respond_to do |format|
      format.html
    end
  end


  def my_sets
    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:find_user_compilations]

    @forced_view = "drs-items-list"

    (@response, @compilations) = get_search_results

    respond_to do |format|
      format.js {
        if @response.response['numFound'] < 1
          render js: "$('#my').replaceWith('<div class=\"alert alert-info\">You have not created any #{t('drs.compilations.name') + 's'} yet! Create a new #{t('drs.compilations.name')} today.</div>');"
        else
          render "my"
        end
      }
    end
  end

  def editable_compilations
    # use this for the popup when adding to sets
    u_groups = current_user.groups
    groups = u_groups.map! { |g| "\"#{g}\""}.join(" OR ")
    @compilations = solr_query("(depositor_tesim:\"#{current_user.nuid}\" OR edit_access_group_ssim:(#{groups})) AND has_model_ssim:\"#{ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Compilation"}\"")
    if params[:class] == 'Collection'
      doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:file]}\"").first)
    end

    respond_to do |format|
      if doc && doc.klass == 'Collection' && doc.child_collections.length > 0
        format.js{
          render js: "$('#ajax-modal .modal-body').text('Collections that contain other collections cannot be added to a #{t('drs.compilations.name').capitalize}. Please open this collection and select the specific files or collections you would like to add to your #{t('drs.compilations.name').capitalize}.'); $('#ajax-modal').modal('show'); $('#ajax-modal-heading').text('Add to a #{t('drs.compilations.name').capitalize}'); $('#ajax-modal-footer').html('<button class=\"btn\" data-dismiss=\"modal\">Close</button>');"
         }
      else
        format.js{ render "editable" }
      end
    end
  end

  def collaborative_compilations
    self.solr_search_params_logic += [:exclude_unwanted_models]
    self.solr_search_params_logic += [:get_compilations_with_permissions]

    @forced_view = "drs-items-list"

    (@response, @compilations) = get_search_results

    respond_to do |format|
      format.js {
        if @response.response['numFound'] < 1
          render js: "$('#collaborative').replaceWith('<div class=\"alert alert-info\">You have no collaborative #{t('drs.compilations.name').capitalize.pluralize} yet. Collaborative #{t('drs.compilations.name').pluralize} are #{t('drs.compilations.name').pluralize} that are created by other users but editable by you.</div>');"
        else
          render "collaborative"
        end
      }
    end
  end

  def new
    @set = Compilation.new
    @page_title = "New " + t('drs.compilations.name').capitalize
    respond_to do |format|
      format.js { render 'new' }
      format.html { render 'shared/sets/new' }
    end
  end

  def create
    @compilation = Compilation.new(params[:compilation].merge(pid: mint_unique_pid))

    if !params[:entry_id].blank?
      @compilation.add_entry(params[:entry_id])
    end

    @compilation.depositor = current_user.nuid
    @compilation.mass_permissions = params[:mass_permissions]

    save_or_bust @compilation
    redirect_to @compilation
  end

  def edit
    @page_title = "Edit #{@compilation.title}"
    @set = @compilation
    render :template => 'shared/sets/edit'
  end

  def update
    @compilation.mass_permissions = params[:mass_permissions]

    if @compilation.update_attributes(params[:compilation])
      flash[:notice] = "#{t('drs.compilations.name').capitalize} successfully updated."
      redirect_to @compilation
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} failed to update."
    end
  end

  def show
    @page_title = "#{@compilation.title}"
    if !@compilation.description.blank?
      @pretty_description = convert_urls(@compilation.description)
    end

    if params['q']
      params.delete :q # this disables querying compilations
    end

    @set = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@compilation.pid}\"").first)
    self.solr_search_params_logic += [:filter_entry_ids]
    (@response, @document_list) = get_search_results
    if @response.response['numFound'] == 0
      flash[:notice] = "There are no items in this #{t('drs.compilations.name').capitalize}. Please search or browse for an item or collection and add it to this #{t('drs.compilations.name').capitalize}."
    end
    if @compilation.entry_ids.length != @response.response['numFound']
      dead_entries = @compilation.remove_dead_entries
    end

    respond_to do |format|
      format.html{ render "shared/sets/show", locals: {pretty_description: @pretty_description}}
      format.json{ render json: @compilation  }
    end
  end

  def destroy
    if @compilation.destroy
      flash[:notice] = "#{t('drs.compilations.name').capitalize} was successfully deleted"
      redirect_to compilations_path
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} #{@compilation.title} was not successfully destroyed"
    end
  end

  def add_entry
    doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:entry_id]}\"").first)
    if doc.klass == "Collection"
      col_pids = []
      doc.all_descendent_files.each do |f|
        col_pids << f.pid
      end
    end
    respond_to do |format|
      if col_pids && !(@compilation.entry_ids & col_pids).empty?
        intersection = @compilation.entry_ids & col_pids
        if params[:proceed]
          intersection.each do |i|
            @compilation.remove_entry(i)
            save_or_bust @compilation
          end
          @compilation.add_entry(params[:entry_id])
          save_or_bust @compilation
          format.json { render :json => {:status=>"Collection successfully added to set"}, status: 200}
        else
          format.json { render :json => { :error => "Some files in this collection already exist in \"#{@compilation.title}\". If you add this collection to the Set, the duplicate files will be removed.", :title => "Add to \"#{@compilation.title}\"", :set=>@compilation.pid, :entry_id=>params[:entry_id]}, status: :unprocessable_entity}
        end
      elsif (@compilation.object_ids.include? params[:entry_id])
        format.json { render :json => { :error => "This object is already in the #{t('drs.compilations.name').capitalize}." }, status: :unprocessable_entity}
      elsif @compilation.add_entry(params[:entry_id])
        save_or_bust @compilation
        format.html { redirect_to @compilation }
        format.json { render :nothing => true }
        format.js   { render :nothing => true }
      else
        format.json { render json: {error: "There was an error adding this item to the #{t('drs.compilations.name').capitalize}. Please go back and try a different object."}.to_json, status: :unprocessable_entity }
      end
    end
  end

  def add_entry_dups
    doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:entry_id]}\"").first)
    if doc.klass == "Collection"
      col_pids = []
      doc.all_descendent_files.each do |f|
        col_pids << f.pid
      end
    end
    if col_pids && !(@compilation.entry_ids & col_pids).empty?
      intersection = @compilation.entry_ids & col_pids
      intersection.map!{|i| i=SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{i}\"").first)}
      intersection.sort_by! { |c| c.title }
      respond_to do |format|
        format.js{render "dups", locals:{intersection:intersection}}
      end
    end
  end

  def check_multiple_entries
    entries = params[:entries]
    intersection = (entries & @compilation.object_ids).to_a
    if !intersection.empty?
      intersection.each do |i|
        entries.delete(i)
      end
    end

    respond_to do |format|
      if entries.count > 0
        format.js{ render "check_multi_add", locals: {entries: entries, compilation: @compilation, dup_count: intersection.length} }
      else
        format.js{
          render js: "$(\"#ajax-modal .modal-body\").text(\"#{intersection.count} items are already in #{@compilation.title}\"); $(\"#ajax-modal\").modal(\"show\"); $(\"#ajax-modal-heading\").text('Add to \"#{@compilation.title}\"'); $(\"#ajax-modal-footer\").html(\"<button class='btn' data-dismiss='modal'>Close</button>\");"
         }
      end
    end

  end

  def add_multiple_entries
    entries = params[:entry_ids]
    entries.each do |e|
      @compilation.add_entry(e)
    end
    save_or_bust @compilation
    respond_to do |format|
      format.html { redirect_to @compilation }
      format.json { render :nothing => true }
      format.js   { render :nothing => true }
    end
  end

  def delete_multiple_entries
    params[:entry_ids].each do |e|
      @compilation.remove_entry(e)
    end
    save_or_bust @compilation
    respond_to do |format|
      format.html { redirect_to @compilation }
      format.json { render :nothing => true }
      format.js   { render :nothing => true }
    end
  end

  def delete_entry
    respond_to do |format|
      this_entry = params[:entry_id]
      if @compilation.entry_ids.include?(this_entry)
        @compilation.remove_entry(this_entry)
        save_or_bust @compilation
        format.html { redirect_to @compilation }
        format.json { render :nothing => true }
        format.js   { render :nothing => true }
      elsif @compilation.object_ids.include?(this_entry)
        format.json { render :json => { :error => "This item cannot be removed from the #{t('drs.compilations.name').capitalize} because it belongs to a collection that already exists in the #{t('drs.compilations.name').capitalize}.<br><br> If you wish to remove this item, remove the collection from the #{t('drs.compilations.name').capitalize} first.<br><br> #{ActionController::Base.helpers.link_to("Go to #{@compilation.title}", compilation_path(@compilation))}"}, status: :unprocessable_entity}
      else
        format.json { render :json => { :error => "There was an error removing this item from the #{t('drs.compilations.name').capitalize}", status: :unprocessable_entity} }
      end
    end
  end

  def ping_download
    respond_to do |format|
      format.js do
        if File.file?(safe_zipfile_name)
          render("ping_download")
        else
          render :nothing => true
        end
      end
    end
  end

  def show_download
    size = 0
    @set = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
    @set.object_ids.each do |i|
      doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{i}\"").first)
      if doc.klass == 'CoreFile' && !doc.tombstoned? && (!current_user.nil? ? current_user.can?(:read, doc) : doc.public?)
        co = doc.canonical_object.first
        if !co.blank?
          size = size + co.file_size.to_f
        end
      end
    end
    size = (size / 1024000).round(2)

    if size > 5000
      params[:action] = "show"
      redirect_to url_for(params.merge(:large=>true))
    else
      Cerberus::Application::Queue.push(ZipCompilationJob.new(current_user, @compilation))
      @page_title = "Download #{@compilation.title}"
    end
  end

  def download
    path_to_dl = Dir["#{Rails.application.config.tmp_path}/#{params[:id].gsub(":", "_")}/*"].first
    send_file path_to_dl
  end

  def request_delete
    set = @compilation
    title = set.title
    user = current_user
    reason = params[:reason]
    DeleteMailer.delete_alert(set, reason, user).deliver!
    flash[:notice] = "Your request has been received and will be processed soon."
    redirect_to set and return
  end

  def get_total_count
    @count = total_count
    respond_to do |format|
      format.js { render "count", locals:{count:@count}}
    end
  end

  def total_count
    @set = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
    docs = []
    @set.entries.each do |e|
      if e.klass == 'CoreFile'
        docs << e
      else
        e.all_descendent_files.each do |f|
          docs << f
        end
      end
    end
    docs.select! { |doc| (doc.public? || (!current_user.nil? && current_user.can?(:read, doc.pid))) }
    @count = docs.count
    return @count
  end

  private
  def save_or_bust(compilation)
    if compilation.save!
      flash[:notice] = "#{t('drs.compilations.name').capitalize} successfully updated"
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} was not successfully updated"
    end
  end

  def filter_entry_ids(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    query = @compilation.entry_ids.map do |pid|
      "id:\"#{pid}\""
    end

    fq = query.join(" OR ")
    if !fq.blank?
      solr_parameters[:fq] << fq
      solr_parameters[:fq] << "!tombstoned_ssi:\"true\""
    else
      solr_parameters[:fq] << "id:\"\""
    end
  end

  def find_user_compilations(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "#{Solrizer.solr_name("depositor", :stored_searchable)}:\"#{current_user.nuid}\""
  end

  def exclude_unwanted_models(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "#{Solrizer.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:Compilation\""
  end

  def get_compilations_with_permissions(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "!#{Solrizer.solr_name("depositor", :stored_searchable)}:\"#{current_user.nuid}\""
    u_groups = current_user.groups
    query = u_groups.map! { |g| "\"#{g}\""}.join(" OR ")
    solr_parameters[:fq] << "edit_access_group_ssim:(#{query})"
  end

  private

  def safe_zipfile_name
    safe_title = @compilation.title.gsub(/\s+/, "")
    safe_title = safe_title.gsub(":", "_")
    return "#{Rails.application.config.tmp_path}/#{@compilation.pid.gsub(":", "_")}/#{safe_title}.zip"
  end
end
