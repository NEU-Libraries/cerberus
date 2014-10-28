require 'stanford-mods'

# -*- coding: utf-8 -*-
class CoreFilesController < ApplicationController
  include Cerberus::Controller
  include Cerberus::TempFileStorage
  include Cerberus::ControllerHelpers::EditableObjects
  include Cerberus::ControllerHelpers::ViewLogger

  include ModsDisplay::ControllerExtension

  before_filter :authenticate_user!, except: [:show]

  skip_before_filter :normalize_identifier
  skip_load_and_authorize_resource only: [:provide_metadata,
                                          :rescue_incomplete_file,
                                          :destroy_incomplete_file,
                                          :process_metadata,
                                          :edit,
                                          :update,
                                          :destroy]

  before_filter :can_edit_parent_or_proxy_upload?, only: [:new, :create]

  before_filter :can_read?, only: [:show]
  before_filter :can_edit?, only: [:edit, :update, :destroy_incomplete_file]
  before_filter :complete?, only: [:edit, :update]

  rescue_from Exceptions::NoParentFoundError, with: :no_parent_rescue

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Object"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end

  configure_mods_display do
    access_condition do
      display!
    end
    subject do
      delimiter " -- "
    end
    identifier do
      ignore!
    end
  end

  def destroy_incomplete_file
    @core_file = fetch_solr_document

    if @core_file.in_progress? && (@core_file.klass == "CoreFile")
      @core_file = CoreFile.find(@core_file.pid)
      @core_file.destroy
      flash[:notice] = "Incomplete file destroyed"
      redirect_to(root_path) and return
    else
      flash[:alert] = "File not destroyed"
      redirect_to(root_path) and return
    end
  end

  def provide_metadata
    @core_file = CoreFile.find(params[:id])

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

    if @core_file.proxy_uploader.present?
      depositor_nuid = @core_file.proxy_uploader
      proxy_nuid     = current_user.nuid
    else
      depositor_nuid = current_user.nuid
      proxy_nuid     = nil
    end

    Cerberus::Application::Queue.push(MetadataUpdateJob.new(depositor_nuid, params, proxy_nuid))

    update_metadata if params[:core_file]
    max = session[:slider_max]

    # Process Thumbnail
    if params[:poster]
      file = params[:poster]
      new_path = move_file_to_tmp(file)

      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename, new_path))
    elsif !max.nil?
      s = params[:small_image_size].to_f / max.to_f
      m = params[:medium_image_size].to_f / max.to_f
      l = params[:large_image_size].to_f / max.to_f

      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename, nil, s, m, l))
    else
      Cerberus::Application::Queue.push(ContentCreationJob.new(@core_file.pid, @core_file.tmp_path, @core_file.original_filename))
    end

    redirect_to core_file_path(@core_file.pid)
  end

  # routed to /files/:id
  def show
    @core_file = fetch_solr_document

    @mods = fetch_mods

    @thumbs = @core_file.thumbnail_list
    @page_title = @core_file.title

    log_action("view", "COMPLETE")

    if @core_file.in_progress?
      flash[:notice] = 'Your files are being processed by ' + t('drs.product_name.short') + ' in the background. The metadata and access controls you specified are being applied. Files will be marked <span class="label label-warning" title="Updating">Updating</span> until this process is complete (shouldn\'t take too long, hang in there!).'
    end
  end

  def create
    begin
      # check error condition No files
      return json_error("Error! No file to save") if !params.has_key?(:file)

      file = params[:file]
      if !file
        flash[:error] = "Error! No file for upload"
        redirect_to(:back) and return
      elsif (empty_file?(file))
        flash[:error] = "Error! Zero Length File!"
        redirect_to(:back) and return
      elsif (!terms_accepted?)
        flash[:error] = "You must accept the terms of service!"
        redirect_to(:back) and return
      elsif current_user.proxy_staff? && params[:upload_type].nil?
        flash[:error] = "You must select whether this is a proxy or personal upload"
        redirect_to(:back) and return
      else
        process_file(file)
      end
    rescue => exception
      logger.error "CoreFilesController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
      email_handled_exception(exception)
      json_error "Error occurred while creating core file."
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

    @core_file = ::CoreFile.new
    @collection_id = params[:parent]
  end

  def edit
    @core_file = CoreFile.find(params[:id])
    @page_title = "Edit #{@core_file.title}"
  end

  def update
    @core_file = CoreFile.find(params[:id])

    version_event = false

    if params.has_key?(:revision) and params[:revision] !=  @core_file.content.latest_version.versionID
      revision = @core_file.content.get_version(params[:revision])
      @core_file.add_file(revision.content, datastream_id, revision.label)
      version_event = true
      Cerberus::Application::Queue.push(ContentRestoredVersionEventJob.new(@core_file.pid, current_user.user_key, params[:revision]))
    end

    if params.has_key?(:filedata)
      file = params[:filedata]
      return unless virus_check(file) == 0
      @core_file.add_file(file, datastream_id, file.original_filename)
      version_event = true
      Cerberus::Application::Queue.push(ContentNewVersionEventJob.new(@core_file.pid, current_user.user_key))
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

      # do not trigger an update event if a version event has already been triggered
      Cerberus::Application::Queue.push(ContentUpdateEventJob.new(@core_file.pid, current_user.user_key)) unless version_event
      # @core_file.record_version_committer(current_user)
    end

    redirect_to(@core_file)
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

    def update_metadata
      valid_permissions = true

      # screen permissions for correct groups...
      existing_groups = @core_file.rightsMetadata.groups.keys - ["public"]
      user_groups = current_user.groups

      valid_groups = existing_groups.zip(user_groups).flatten.compact

      form_groups = params[:core_file]["permissions"]["identity"]

      form_groups.each do |group|
        if !valid_groups.include?(group)
          valid_permissions = false
        end
      end

      if valid_permissions
        @core_file.update_attributes(params[:core_file])
      else
        # someone has manually tampered with the form to circumvent group permissions...
        email_handled_exception(Exceptions::GroupPermissionsError.new(valid_groups, form_groups, current_user.name))
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

      # Context derived attributes
      core_file.tag_as_in_progress
      core_file.title = file.original_filename
      core_file.tmp_path = tmp_path
      core_file.original_filename = file.original_filename
      core_file.label = file.original_filename

      core_file.instantiate_appropriate_content_object(tmp_path, file.original_filename)

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

      core_file.save!
      return core_file
    end

    def process_file(file)
      if virus_check(file) == 0
        @core_file = ::CoreFile.new

        new_path = move_file_to_tmp(file)

        update_metadata_from_upload_screen(@core_file, file, params[:collection_id], new_path, params[:upload_type])
        redirect_to files_provide_metadata_path(@core_file.pid)
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
end
