require 'stanford-mods'

# -*- coding: utf-8 -*-
class NuCoreFilesController < ApplicationController
  include Drs::Controller
  include Drs::ControllerHelpers::EditableObjects
  include Drs::ControllerHelpers::ViewLogger

  include ModsDisplay::ControllerExtension

  before_filter :authenticate_user!, except: [:show]

  skip_before_filter :normalize_identifier # , only: [:provide_metadata, :rescue_incomplete_files, :destroy_incomplete_files, :process_metadata]
  skip_load_and_authorize_resource only: [:provide_metadata,
                                          :rescue_incomplete_files,
                                          :destroy_incomplete_files,
                                          :process_metadata,
                                          :edit,
                                          :update,
                                          :destroy]

  before_filter :can_edit_parent?, only: [:new]

  before_filter :can_read?, only: [:show]
  before_filter :can_edit?, only: [:edit, :update]
  before_filter :is_depositor?, only: [:destroy]

  rescue_from Exceptions::NoParentFoundError, with: :no_parent_rescue

  rescue_from ActiveFedora::ObjectNotFoundError do |exception|
    @obj_type = "Object"
    email_handled_exception(exception)
    render_404(ActiveFedora::ObjectNotFoundError.new) and return
  end

  def destroy_incomplete_files
    NuCoreFile.in_progress_files_for_nuid(current_user.nuid).each do |file|
      file.destroy
    end

    flash[:notice] = "Incomplete files destroyed"
    redirect_to root_path
  end

  def provide_metadata
    # Feeding through an incomplete file if there is one
    @nu_core_file = NuCoreFile.new

    if should_proxy?
      nuid = params[:proxy]
    else
      nuid = current_user.nuid
    end

    @incomplete_file = NuCoreFile.in_progress_files_for_nuid(nuid).first


    @title = @incomplete_file.title

    # With the move to single file upload, incomplete files (plural) is a misnomer.
    # but worthwhile to keep if we reimplement batch uploads. In the meantime only
    # NuCoreFile.in_progress_files_for_nuid(x).first should ever occur (not more than one at a time).

    # @sample_incomplete_file = NuCoreFile.in_progress_files_for_nuid(current_user.nuid).first
    # @incomplete_files = NuCoreFile.in_progress_files_for_nuid(current_user.nuid)
    @page_title = "Provide Upload Metadata"
  end

  # routed to files/rescue_incomplete_files
  # page for allowing users to either permanently delete or apply metadata to
  # files abandoned without completing step two of the upload process.
  def rescue_incomplete_files
    file_titles = []

    request.query_parameters.each do |key, pid|
      file_titles << NuCoreFile.find(pid).title
    end

    @incomplete_file_titles = file_titles
    @page_title = "Rescue abandoned files"
  end

  def process_metadata
    if should_proxy?
      depositor_nuid = params[:proxy]
      proxy_nuid     = current_user.nuid
    else
      depositor_nuid = current_user.nuid
      proxy_nuid     = nil
    end

    Drs::Application::Queue.push(MetadataUpdateJob.new(depositor_nuid, params, proxy_nuid))
    @nu_core_file = NuCoreFile.in_progress_files_for_nuid(depositor_nuid).first

    update_metadata if params[:nu_core_file]

    max = session[:slider_max]

    @nu_core_file = NuCoreFile.find(@nu_core_file.pid)

    # Process Thumbnail
    if params[:poster]
      file = params[:poster]
      # We move the file contents to a more permanent location so that our ContentCreationJob can access them.
      # An ensure block in that job handles cleanup of this file.
      tempdir = Rails.root.join("tmp")
      poster_path = tempdir.join("#{file.original_filename}")
      FileUtils.mv(file.tempfile.path, poster_path.to_s)

      Drs::Application::Queue.push(ContentCreationJob.new(@nu_core_file.pid, @nu_core_file.tmp_path, @nu_core_file.original_filename, poster_path.to_s))
    elsif !max.nil?
      s = params[:small_image_size].to_f / max.to_f
      m = params[:medium_image_size].to_f / max.to_f
      l = params[:large_image_size].to_f / max.to_f

      Drs::Application::Queue.push(ContentCreationJob.new(@nu_core_file.pid, @nu_core_file.tmp_path, @nu_core_file.original_filename, nil, s, m, l))
    else
      Drs::Application::Queue.push(ContentCreationJob.new(@nu_core_file.pid, @nu_core_file.tmp_path, @nu_core_file.original_filename))
    end

    flash[:notice] = 'Your files are being processed by ' + t('drs.product_name.short') + ' in the background. The metadata and access controls you specified are being applied. Files will be marked <span class="label label-important" title="Private">Private</span> until this process is complete (shouldn\'t take too long, hang in there!).'
    redirect_to nu_core_file_path(@nu_core_file.pid)
  end

  # routed to /files/:id
  def show
    @nu_core_file = fetch_solr_document

    @mods = fetch_mods

    @thumbs = @nu_core_file.thumbnail_list
    @page_title = @nu_core_file.title

    log_action("view", "COMPLETE")
  end

  def create
    begin
      # check error condition No files
      return json_error("Error! No file to save") if !params.has_key?(:file)

      file = params[:file]
      if !file
        json_error "Error! No file for upload", 'unknown file', :status => :unprocessable_entity
      elsif (empty_file?(file))
        json_error "Error! Zero Length File!", file.original_filename
      elsif (!terms_accepted?)
        json_error "You must accept the terms of service!", file.original_filename
      elsif (!params[:proxy].blank? && !(Employee.exists_by_nuid? params[:proxy]))
        flash[:alert] = "The NUID you entered, #{params[:proxy]}, doesn't exist in the system"
        redirect_to new_nu_core_file_path( {parent: params[:collection_id]} )
      else
        process_file(file)
      end
    rescue => exception
      logger.error "NuCoreFilesController::create rescued #{exception.class}\n\t#{exception.to_s}\n #{exception.backtrace.join("\n")}\n\n"
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
    in_progress_files = NuCoreFile.in_progress_files_for_nuid(current_user.nuid)

    if !in_progress_files.empty?

      param_hash = {}
      in_progress_files.each_with_index do |file, index|
        param_hash = param_hash.merge({"file#{index}" => file.pid})
      end

      redirect_to rescue_incomplete_files_path(param_hash) and return
    end

    @nu_core_file = ::NuCoreFile.new
    @collection_id = params[:parent]
  end

  def edit
    @nu_core_file = NuCoreFile.find(params[:id])
    @page_title = "Edit #{@nu_core_file.title}"
  end

  def update
    @nu_core_file = NuCoreFile.find(params[:id])

    version_event = false

    if params.has_key?(:revision) and params[:revision] !=  @nu_core_file.content.latest_version.versionID
      revision = @nu_core_file.content.get_version(params[:revision])
      @nu_core_file.add_file(revision.content, datastream_id, revision.label)
      version_event = true
      Drs::Application::Queue.push(ContentRestoredVersionEventJob.new(@nu_core_file.pid, current_user.user_key, params[:revision]))
    end

    if params.has_key?(:filedata)
      file = params[:filedata]
      return unless virus_check(file) == 0
      @nu_core_file.add_file(file, datastream_id, file.original_filename)
      version_event = true
      Drs::Application::Queue.push(ContentNewVersionEventJob.new(@nu_core_file.pid, current_user.user_key))
    end

    # only update metadata if there is a nu_core_file object which is not the case for version updates
    update_metadata if params[:nu_core_file]

    #always save the file so the new version or metadata gets recorded
    if @nu_core_file.save
      if params[:nu_core_file] && !@nu_core_file.category.first.blank?
        UploadAlert.create_from_core_file(@nu_core_file, :update)
      end

      # If this change updated metadata, propagate the change outwards to
      # all content objects
      if params[:nu_core_file]
        q = Drs::Application::Queue
        q.push(PropagateCoreMetadataChangeJob.new(@nu_core_file.pid))
      end

      # do not trigger an update event if a version event has already been triggered
      Drs::Application::Queue.push(ContentUpdateEventJob.new(@nu_core_file.pid, current_user.user_key)) unless version_event
      # @nu_core_file.record_version_committer(current_user)
    end

    redirect_to(@nu_core_file)
  end

  protected

    def fetch_mods
      Rails.cache.fetch("/mods/#{@nu_core_file.pid}-#{@nu_core_file.updated_at}", :expires_in => 12.hours) do
        render_mods_display(NuCoreFile.find(@nu_core_file.pid)).to_html.html_safe
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
      # @nu_core_file.date_modified = DateTime.now.to_s
      @nu_core_file.update_attributes(params[:nu_core_file])
    end

    #Allows us to map different params
    def update_metadata_from_upload_screen(nu_core_file, file, collection_id, tmp_path, proxy)
      # Relative path is set by the jquery uploader when uploading a directory
      nu_core_file.relative_path = params[:relative_path] if params[:relative_path]

      if !proxy.blank? && current_user.proxy_staff?
        nu_core_file.depositor = proxy
        nu_core_file.proxy_uploader = current_user.nuid
      else
        nu_core_file.depositor = current_user.nuid
      end

      # Context derived attributes
      nu_core_file.tag_as_in_progress
      nu_core_file.title = file.original_filename
      nu_core_file.tmp_path = tmp_path
      nu_core_file.original_filename = file.original_filename
      nu_core_file.label = file.original_filename

      nu_core_file.instantiate_appropriate_content_object(tmp_path, file.original_filename)

      # If the content_object created is an ImageMasterFile, we want to read the image and store as session vars
      # the length of its longest side.  This is used to calculate the dimensions to allow for the small/med/large
      # sliders on the Provide Metadata page.
      if nu_core_file.canonical_class == "ImageMasterFile"
        session[:slider_max] = nil # Ensure we aren't using data from a prior upload
        session[:slider_max] = SliderMaxCalculator.compute(tmp_path)
      end

      collection = !collection_id.blank? ? NuCollection.find(collection_id) : nil
      nu_core_file.set_parent(collection, current_user) if collection

      # Significant content tagging
      sc_type = collection.smart_collection_type

      if !sc_type.nil? && sc_type != ""
        nu_core_file.category = sc_type
      end

      yield(nu_core_file) if block_given?
      nu_core_file.save!
    end

    def process_file(file)
      if virus_check(file) == 0
        @nu_core_file = ::NuCoreFile.new

        # We move the file contents to a more permanent location so that our ContentCreationJob can access them.
        # An ensure block in that job handles cleanup of this file.
        tempdir = Rails.root.join("tmp")
        new_path = tempdir.join("#{file.original_filename}")
        FileUtils.mv(file.tempfile.path, new_path.to_s)

        update_metadata_from_upload_screen(@nu_core_file, file, params[:collection_id], new_path.to_s, params[:proxy])
        # @nu_core_file.record_version_committer(current_user)
        redirect_to files_provide_metadata_path({proxy: params[:proxy]})
      else
        render :json => [{:error => "Error creating file."}]
      end
    end

    def virus_check( file)
      stat = Drs::NuCoreFile::Actions.virus_check(file)
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

    def should_proxy?
      if ( !params[:proxy].blank?)
        current_user.proxy_staff? && Employee.exists_by_nuid(params[:proxy])
      end
    end
end
