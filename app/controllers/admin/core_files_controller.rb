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
  include Cerberus::TempFileStorage
  include MimeHelper
  include ChecksumHelper

  before_filter :authenticate_user!
  before_filter :verify_admin

  def new_replacement_file
    flash[:alert] = "This process is not reversible. Replaced items are deleted."
    @content_object = ActiveFedora::Base.find(params[:id], cast: true)
    render 'core_files/new_replacement_file'
  end

  def create_replacement_file
    file = params[:file]
    file_name = file.original_filename
    file_path = move_file_to_tmp(file)

    old_content_object = ActiveFedora::Base.find(params[:old_id], cast: true)

    mime_type = extract_mime_type(file_path, file_name)
    extension = extract_extension(mime_type, File.extname(file_name))

    if old_content_object.mime_type != mime_type
      flash[:error] = "Mime type must be #{old_content_object.mime_type} not #{mime_type}"
      redirect_to root_path and return
    end

    if File.extname(old_content_object.original_filename) != extension
      flash[:error] = "Extension must be #{File.extname(old_content_object.original_filename)} not #{extension}"
      redirect_to root_path and return
    end

    core_record = CoreFile.find(old_content_object.core_record.pid)
    content_object = old_content_object.class.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))

    uri = URI("#{ActiveFedora.config.credentials[:url]}/objects/#{content_object.pid}/datastreams/content?controlGroup=M&dsLocation=file://#{file_path}")
    Net::HTTP.start(uri.host, uri.port) do |http|
      http.read_timeout = 60000
      request = Net::HTTP::Post.new uri
      request.basic_auth("#{ActiveFedora.config.credentials[:user]}", "#{ActiveFedora.config.credentials[:password]}")
      res = http.request request # Net::HTTPResponse object
    end

    content_object.reload
    content_object.rightsMetadata.content = old_content_object.rightsMetadata.content
    content_object.core_record = core_record
    content_object.save!

    content_object.original_filename = file_name
    content_object.properties.mime_type = mime_type
    content_object.properties.md5_checksum = new_checksum(file_path)
    content_object.properties.file_size = File.size(file_path).to_s

    if old_content_object.canonical?
      content_object.canonize
    end

    content_object.save!

    old_content_object.destroy
    invalidate_pid(core_record.pid)

    flash[:success] = "File was replaced successfully."
    redirect_to root_path and return
  end

  def index
    @page_title = "Administer Core Files"
  end

  # routed to /admin/files/:id
  def show
    @core_file = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first
    @mods = Sanitize.clean(Kramdown::Document.new(render_mods_display(CoreFile.find(@core_file.pid))).to_html, :elements => ['sup', 'sub', 'dt', 'dd', 'br', 'a'], :attributes => {'a' => ['href']}).html_safe
    @thumbs = @core_file.thumbnail_list
    if @core_file.tombstone_reason
      flash.now[:alert] = "#{@core_file.tombstone_reason}"
    end
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
      redirect_to admin_files_path, alert: "The core file '#{title}' could not be revived because the parent '#{ActionController::Base.helpers.link_to parent.title, admin_view_collection_path(parent.pid)}' is tombstoned.".html_safe
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

  def multi_delete
    cfs = params[:ids]
    cfs = cfs.split(',').map(&:strip)
    cf_count = cfs.length
    cfs.each do |cf|
      CoreFile.find(cf).destroy
    end
    redirect_to admin_files_path, notice: "#{cf_count} files have been deleted"
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
      solr_parameters[:sort] = "tombstone_date_ssi desc"
    end
    def limit_to_in_progress(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "in_progress_tesim:\"true\" AND active_fedora_model_ssi:\"CoreFile\""
      solr_parameters[:sort] = "system_modified_dtsi desc"
    end
    def limit_to_incomplete(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "incomplete_tesim:\"true\" AND active_fedora_model_ssi:\"CoreFile\""
      solr_parameters[:sort] = "system_modified_dtsi desc"
    end

end
