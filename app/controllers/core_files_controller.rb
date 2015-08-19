require 'stanford-mods'

# -*- coding: utf-8 -*-
class CoreFilesController < ApplicationController
  include Cerberus::Controller
  include Cerberus::TempFileStorage
  include Cerberus::ControllerHelpers::EditableObjects
  include Cerberus::ControllerHelpers::ViewLogger
  include Cerberus::ControllerHelpers::PermissionsCheck

  include ModsDisplay::ControllerExtension
  include XmlValidator
  include HandleHelper

  before_filter :authenticate_user!, except: [:show]

  skip_before_filter :normalize_identifier
  skip_load_and_authorize_resource only: [:provide_metadata,
                                          :rescue_incomplete_file,
                                          :destroy_incomplete_file,
                                          :process_metadata,
                                          :edit,
                                          :update,
                                          :destroy]

  before_filter :can_edit_parent_or_proxy_upload?, only: [:new, :create, :destroy_incomplete_file]

  before_filter :can_read?, only: [:show]
  before_filter :can_edit?, only: [:edit, :update]
  before_filter :complete?, only: [:edit, :update]

  before_filter :valid_form_permissions?, only: [:process_metadata, :update]

  before_filter :verify_staff_or_beta, only: [:validate_xml, :edit_xml]

  rescue_from Exceptions::NoParentFoundError, with: :no_parent_rescue
  rescue_from Exceptions::GroupPermissionsError, with: :group_permission_rescue

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Object"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end

  rescue_from Exceptions::SearchResultTypeError do |exception|
    # No longer emailing this error - it's always Pat debugging
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end

  configure_mods_display do
    access_condition do
      display!
    end
    subject do
      delimiter " -- "
    end
  end

  def destroy_incomplete_file
    @core_file = fetch_solr_document

    if @core_file.in_progress? && (@core_file.klass == "CoreFile")
      # User completed second screen, so they most likely went back accidentally
      # Do nothing
    elsif @core_file.incomplete?
      @core_file = CoreFile.find(@core_file.pid)
      @core_file.destroy

      respond_to do |format|
        format.html{
            flash[:notice] = "Incomplete file destroyed"
            redirect_to(root_path) and return
          }
        format.js   { render :nothing => true }
      end
    end

    render :nothing => true
  end

  def provide_metadata
    @core_file = CoreFile.find(params[:id])
    @collection = @core_file.parent

    if !@collection.nil? && !@collection.smart_collection_type.blank? && @collection.smart_collection_type != "miscellany"
      flash[:alert] = "Note: You are depositing this file in a Smart Collection. Library staff will review permissions and enhance metadata as needed."
    end

    @title = @core_file.title

    @page_title = "Provide Upload Metadata"
  end

  # routed to files/rescue_incomplete_files
  # page for allowing users to either permanently delete or apply metadata to
  # files abandoned without completing step two of the upload process.
  def rescue_incomplete_file
    if params["abandoned"]
      @incomplete = fetch_solr_document(id: params["abandoned"])
    else
      file = CoreFile.abandoned_for_nuid(current_user.nuid).first
      @incomplete = file
    end

    @page_title = "Rescue abandoned files"
  end

  def process_metadata
    @core_file = CoreFile.find(params[:id])

    # if no title or keyword, send them back. Only God knows what they did to the form...
    # fix for #671
    if !title_and_keyword?
      redirect_to files_provide_metadata_path(@core_file.pid) and return
    end

    # Moved to later in process to prevent accidental deletion
    @core_file.tag_as_in_progress
    @core_file.save!
    @core_file.reload

    if @core_file.proxy_uploader.present?
      depositor_nuid = @core_file.proxy_uploader
      proxy_nuid     = current_user.nuid
    else
      depositor_nuid = current_user.nuid
      proxy_nuid     = nil
    end

    update_metadata if params[:core_file]
    max = session[:slider_max]

    # Process Thumbnail
    if params[:poster]
      file = params[:poster]
      poster_path = move_file_to_tmp(file)
      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename, poster_path))
    elsif !max.nil?
      s = params[:small_image_size].to_f / max.to_f
      m = params[:medium_image_size].to_f / max.to_f
      l = params[:large_image_size].to_f / max.to_f

      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename, nil, s, m, l))
    else
      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename))
    end

    # Add drs staff to permissions for #608
    @core_file.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

    if @core_file.save!
      if params[:core_file] && !@core_file.category.first.blank?
        UploadAlert.create_from_core_file(@core_file, :create)
      end
    end

    redirect_to core_file_path(@core_file.pid) + '#no-back'
  end

  # routed to /files/:id
  def show
    @core_file = fetch_solr_document
    @mods = fetch_mods

    begin
      @parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{@core_file.parent}\"").first)
    rescue => exception
      # At this stage most likely a supplemental file
      if @core_file.supplemental_material_for.blank?
        email_handled_exception(exception)
      end
    end

    @thumbs = @core_file.thumbnail_list
    @page_title = "#{@core_file.non_sort} #{@core_file.title}"

    log_action("view", "COMPLETE")

    if @core_file.in_progress?
      flash[:notice] = 'Your files are being processed by ' + t('drs.product_name.short') + ' in the background. The metadata and access controls you specified are being applied. Files will be marked <span class="label label-warning" title="Updating">Updating</span> until this process is complete (shouldn\'t take too long, hang in there!).'
    end

    if ((Time.now.utc - DateTime.parse(@core_file.updated_at)) / 1.hour) < 1
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    end
  end

  def create
    begin
      # check error condition No files
      return json_error("Error! No file to save") if !params.has_key?(:file)

      file = params[:file]
      if !file
        session[:flash_error] = "Error! No file for upload"
        render :json => { url: session[:previous_url] }
      elsif (empty_file?(file))
        session[:flash_error] = "Error! Zero Length File!"
        render :json => { url: session[:previous_url] }
      elsif ((File.size(file.tempfile).to_f / 1024000).round(2) > 500) #500 is 500MB
        session[:flash_error] = "The file you chose is larger than 500MB. Please contact DRS staff for help uploading files larger than 500MB."
        render :json => { url: session[:previous_url] }
      elsif (!terms_accepted?)
        session[:flash_error] = "You must accept the terms of service!"
        render :json => { url: session[:previous_url] }
      elsif current_user.proxy_staff? && params[:upload_type].nil?
        session[:flash_error] = "You must select whether this is a proxy or personal upload"
        render :json => { url: session[:previous_url] }
      else
        process_file(file)
      end
    rescue => exception
      logger.error "CoreFilesController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      email_handled_exception(exception)
      json_error "Error occurred while creating file."
    ensure
      # remove the tempfile (only if it is a temp file)
      file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end

  # routed to /files/new
  def new
    @page_title = "Upload New Files"

    abandoned_files = CoreFile.abandoned_for_nuid(current_user.nuid)

    if abandoned_files.any?
      file = abandoned_files.first
      redirect_to rescue_incomplete_file_path("abandoned" => file.pid)
      return
    end

    if session[:flash_error]
      flash[:error] = session[:flash_error]
      session[:flash_error] = nil
    end
    if session[:flash_success]
      flash[:notice] = session[:flash_success]
      session[:flash_success] = nil
    end

    @core_file = ::CoreFile.new
    @collection_id = params[:parent]
  end

  def edit
    @core_file = CoreFile.find(params[:id])
    @page_title = "Edit #{@core_file.title}"
  end

  def edit_xml
    @core_file = CoreFile.find(params[:id])
    @page_title = "Edit #{@core_file.title}'s xml"
    @mods_html = render_mods_display(CoreFile.find(@core_file.pid)).to_html.html_safe
    render :template => 'core_files/ace_xml_editor'
  end

  def validate_xml
    @result = xml_valid?(params[:raw_xml].first)

    if !@result[:errors].blank?
      # Formatting error array for template
      error_list = "<h4 class='xml-error'>Invalid XML provided</h4></br> "
      @result[:errors].each do |entry|
        error_list = error_list.concat("#{entry.class.to_s}: #{entry} </br></br> ")
      end
      @result = error_list
    elsif !params[:commit].blank? && params[:commit] == "Save"
      if !@result[:mods_html].blank?
        # Valid, and ready to save
        @core_file = CoreFile.find(params[:id])

        # Invalidate cache
        Rails.cache.delete_matched("/mods/#{@core_file.pid}*")

        # Email the metadata changes
        new_doc = Nokogiri::XML(params[:raw_xml].first)
        old_doc = Nokogiri::XML(@core_file.mods.content)

        XmlAlert.create_from_strings(@core_file, current_user, old_doc.to_s, new_doc.to_s)

        @core_file.mods.content = params[:raw_xml].first
        @core_file.save!
        @core_file.match_dc_to_mods

        render js: "window.location = '#{core_file_path(@core_file.pid)}'" and return
      end
    else
      @result = @result[:mods_html]
    end

    respond_to do |format|
      format.js
    end
  end

  def update
    @core_file = CoreFile.find(params[:id])

    # Invalidate cache
    Rails.cache.delete_matched("/mods/#{@core_file.pid}*")

    # if no title or keyword, send them back. Only God knows what they did to the form...
    # fix for #671
    if !title_and_keyword?
      redirect_to edit_core_file_path(@core_file.pid) and return
    end

    # only update metadata if there is a core_file object which is not the case for version updates
    update_metadata if params[:core_file]

    #always save the file so the new version or metadata gets recorded
    if @core_file.save
      if params[:core_file] && !@core_file.category.first.blank?
        UploadAlert.create_from_core_file(@core_file, :update)
      end

      # If this change updated metadata, propagate the change outwards to
      # all content objects
      if params[:core_file]
        q = Cerberus::Application::Queue
        q.push(PropagateCoreMetadataChangeJob.new(@core_file.pid))
      end
    end

    redirect_to(@core_file)
  end

  def log_stream
    log_action("stream", "COMPLETE")
    render :nothing => true
  end

  def tombstone
    core_file = CoreFile.find(params[:id])
    title = core_file.title
    collection = core_file.parent.id
    core_file.tombstone
    if current_user.admin?
      redirect_to collection_path(id: collection), notice: "The file '#{title}' has been tombstoned"
    else
      redirect_to collection_path(id: collection), notice: "The file '#{title}' has been tombstoned"
    end
  end

  def request_tombstone
    core_file = CoreFile.find(params[:id])
    title = core_file.title
    collection = core_file.parent.id
    user = current_user
    reason = params[:reason]
    TombstoneMailer.tombstone_alert(core_file, reason, user).deliver!
    flash[:notice] = "Your request has been received and will be processed soon."
    redirect_to core_file and return
  end

  def request_move
    core_file = CoreFile.find(params[:id])
    title = core_file.title
    collection = core_file.parent.id
    user = current_user
    reason = params[:reason]
    collection_url = params[:collection_url]
    collection_pid = collection_url[/([^\/]+)$/]
    if Collection.exists?(collection_pid)
      MoveMailer.move_alert(core_file, reason, collection_url, user).deliver!
      flash[:notice] = "Your request has been received and will be processed soon."
      redirect_to core_file and return
    else
      flash[:error] = "That collection does not exist. Please submit a new request and enter a valid collection URL."
      redirect_to core_file and return
    end
  end

  protected

    def complete?
      core = CoreFile.find(params[:id])
      if core.properties.in_progress?
        flash[:error] = "Item will be available for edit/update when it has finished building."
        redirect_to core and return
      end
    end

    def fetch_mods
      Rails.cache.fetch("/mods/#{@core_file.pid}-#{@core_file.updated_at}", :expires_in => 12.hours) do
        render_mods_display(CoreFile.find(@core_file.pid)).to_html.html_safe
      end
    end

    def json_error(error, name=nil, additional_arguments={})
      args = {:error => error}
      args[:name] = name if name
      render additional_arguments.merge({:json => [args]})
    end

    def no_parent_rescue(exception)
      flash[:error] = "Parent not specified or invalid"
      email_handled_exception(exception)
      redirect_to root_path
    end

    def group_permission_rescue(exception)
      flash[:error] = "Invalid form values"
      email_handled_exception(exception)
      redirect_to root_path
    end

    def update_metadata
      if @core_file.update_attributes(params[:core_file])
        flash[:notice] =  "#{@core_file.title} was updated successfully."
      end
    end

    #Allows us to map different params
    def update_metadata_from_upload_screen(core_file, file, collection_id, tmp_path, proxy)

      if current_user.proxy_staff? && proxy == "proxy"
        core_file.depositor = Collection.find(collection_id).depositor
        core_file.proxy_uploader = current_user.nuid
      else
        core_file.depositor = current_user.nuid
      end

      core_file.tag_as_incomplete
      core_file.save!
      core_file.reload

      # Context derived attributes
      core_file.title = file.original_filename
      core_file.tmp_path = tmp_path
      core_file.original_filename = file.original_filename
      core_file.label = file.original_filename

      core_file.instantiate_appropriate_content_object(tmp_path)

      # If the content_object created is an ImageMasterFile, we want to read the image and store as session vars
      # the length of its longest side.  This is used to calculate the dimensions to allow for the small/med/large
      # sliders on the Provide Metadata page.
      if core_file.canonical_class == "ImageMasterFile"
        session[:slider_max] = nil # Ensure we aren't using data from a prior upload
        session[:slider_max] = SliderMaxCalculator.compute(tmp_path)
      end

      collection = !collection_id.blank? ? Collection.find(collection_id) : nil
      core_file.set_parent(collection, current_user) if collection

      # Featured Content tagging
      sc_type = collection.smart_collection_type

      if !sc_type.nil? && sc_type != ""
        core_file.category = sc_type
      end

      # Create a handle
      core_file.identifier = make_handle(core_file.persistent_url)

      core_file.save!
      return core_file
    end

    def process_file(file)
      if virus_check(file) == 0
        @core_file = ::CoreFile.new

        new_path = move_file_to_tmp(file)

        update_metadata_from_upload_screen(@core_file, file, params[:collection_id], new_path, params[:upload_type])
        respond_to do |format|
          format.json { render json: { url: files_provide_metadata_path(@core_file.pid) } }
        end
      else
        render :json => [{:error => "Error creating file."}]
      end
    end

    def virus_check( file)
      stat = Cerberus::ContentFile.virus_check(file)
      flash[:error] = "Virus checking did not pass for #{File.basename(file.path)} status = #{stat}" unless stat == 0
      stat
    end

    def empty_file?(file)
      (file.respond_to?(:tempfile) && file.tempfile.size == 0) || (file.respond_to?(:size) && file.size == 0)
    end

    # The name of the datastream where we store the file data
    def datastream_id
      'content'
    end

    def terms_accepted?
      params[:terms_of_service] == '1'
    end

    def title_and_keyword?
      if !(params[:core_file][:title].blank?) && !(params[:core_file][:keywords].blank?)
        if !(params[:core_file][:title].first.blank?) && !(params[:core_file][:keywords].first.blank?)
          return true
        end
      end

      # failure case
      flash[:error] = "A title and at least one keyword are required"
      return false
    end

    private

      def verify_staff_or_beta
        if !(current_user.repo_staff? || current_user.beta?)
          flash[:error] = "You do not have privileges to use that feature"
          redirect_to root_path
        end
      end
end
