# -*- coding: utf-8 -*-
# Copyright © 2012 The Pennsylvania State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class NuCoreFilesController < ApplicationController
  include Sufia::Controller
  include Sufia::FilesControllerBehavior
  include Drs::ControllerHelpers::EditableObjects
  include Drs::ControllerHelpers::ViewLogger

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

  after_filter :view_logger, only: [:show]

  rescue_from Exceptions::NoParentFoundError, with: :no_parent_rescue

  rescue_from ActiveFedora::ObjectNotFoundError do
    @obj_type = "Object"
    render "error/object_404"      
  end

  def destroy_incomplete_files
    NuCoreFile.users_in_progress_files(current_user).each do |file|
      file.destroy 
    end

    flash[:notice] = "Incomplete files destroyed" 
    redirect_to new_nu_core_file_path
  end

  def provide_metadata
    @nu_core_file = NuCoreFile.new
    @sample_incomplete_file = NuCoreFile.users_in_progress_files(current_user).first 
    @incomplete_files = NuCoreFile.users_in_progress_files(current_user) 
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
    Sufia.queue.push(MetadataUpdateJob.new(current_user.user_key, params))
    flash[:notice] = 'Your files are being processed by ' + t('sufia.product_name') + ' in the background. The metadata and access controls you specified are being applied. Files will be marked <span class="label label-important" title="Private">Private</span> until this process is complete (shouldn\'t take too long, hang in there!). You may need to refresh your dashboard to see these updates.'
    redirect_to nu_collection_path(params[:collection_id])
  end

  # routed to /files/:id
  def show
    respond_to do |format|
      format.html {
        @events = @nu_core_file.events(100)
        @page_title = @nu_core_file.title
      }
      format.endnote { render :text => @nu_core_file.export_as_endnote }
    end
  end

  # routed to /files/new
  def new
    @page_title = "Upload New Files"
    in_progress_files = NuCoreFile.users_in_progress_files(current_user)

    if !in_progress_files.empty?

      param_hash = {}
      in_progress_files.each_with_index do |file, index| 
        param_hash = param_hash.merge({"file#{index}" => file.pid}) 
      end

      redirect_to rescue_incomplete_files_path(param_hash) and return
    end

    @nu_core_file = ::NuCoreFile.new
    #@batch_noid = Sufia::Noid.noidify(Sufia::IdService.mint)
    @collection_id = params[:parent]      
  end

  def edit
    @nu_core_file = NuCoreFile.find(params[:id])
    @page_title = "Edit #{@nu_core_file.title}" 

    @nu_core_file.initialize_fields
    @groups = current_user.groups
  end

  def update
    @nu_core_file = NuCoreFile.find(params[:id]) 

    version_event = false

    if params.has_key?(:revision) and params[:revision] !=  @nu_core_file.content.latest_version.versionID
      revision = @nu_core_file.content.get_version(params[:revision])
      @nu_core_file.add_file(revision.content, datastream_id, revision.label)
      version_event = true
      Sufia.queue.push(ContentRestoredVersionEventJob.new(@nu_core_file.pid, current_user.user_key, params[:revision]))
    end

    if params.has_key?(:filedata)
      file = params[:filedata]
      return unless virus_check(file) == 0
      @nu_core_file.add_file(file, datastream_id, file.original_filename)
      version_event = true
      Sufia.queue.push(ContentNewVersionEventJob.new(@nu_core_file.pid, current_user.user_key))
    end

    # only update metadata if there is a generic_file object which is not the case for version updates
    update_metadata if params[:nu_core_file]

    #always save the file so the new version or metadata gets recorded
    if @nu_core_file.save
      if params[:nu_core_file] && !@nu_core_file.category.first.blank?
        UploadAlert.create_from_core_file(@nu_core_file, :update)
      end
      # do not trigger an update event if a version event has already been triggered
      Sufia.queue.push(ContentUpdateEventJob.new(@nu_core_file.pid, current_user.user_key)) unless version_event
      @nu_core_file.record_version_committer(current_user)
      redirect_to sufia.edit_generic_file_path(:tab => params[:redirect_tab]), :notice => render_to_string(:partial=>'generic_files/asset_updated_flash', :locals => { :generic_file => @nu_core_file })
    else
      render action: 'edit'
    end
    end

  def destroy
    @title = NuCoreFile.find(params[:id]).title

    if NuCoreFile.find(params[:id]).destroy 
      redirect_to(sufia.dashboard_index_path, notice: "#{@title} destroyed") 
    else
      redirect_to(sufia.dashboard_index_path, notice: "#{@title} wasn't destroyed") 
    end
  end

  def self.upload_complete_path
    Rails.application.routes.url_helpers.files_provide_metadata_path
  end

  protected

 def create_from_local(params)
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
      else
        process_file(file)
      end
    rescue => error
      logger.error "NuCoreFilesController::create rescued #{error.class}\n\t#{error.to_s}\n #{error.backtrace.join("\n")}\n\n"
      json_error "Error occurred while creating generic file."
    ensure
      # remove the tempfile (only if it is a temp file)
      file.tempfile.delete if file.respond_to?(:tempfile)
    end
  end  

  def no_parent_rescue
    flash[:error] = "Parent not specified or invalid" 
    redirect_to root_path 
  end

  def update_metadata 
    @nu_core_file.date_modified = DateTime.now.to_s
    @nu_core_file.update_attributes(params[:nu_core_file]) 
  end

  #Allows us to map different params 
  def update_metadata_from_upload_screen(nu_core_file, user, file, collection_id)
    # Relative path is set by the jquery uploader when uploading a directory
    nu_core_file.relative_path = params[:relative_path] if params[:relative_path]

    # Context derived attributes 
    nu_core_file.depositor = user.nuid 
    nu_core_file.tag_as_in_progress 
    nu_core_file.title = file.original_filename 
    nu_core_file.date_uploaded = Date.today 
    nu_core_file.date_modified = Date.today
    nu_core_file.creator = user.name

    
    collection = !collection_id.blank? ? NuCollection.find(collection_id) : nil
    nu_core_file.set_parent(collection, user) if collection

    # Significant content tagging
    pf_type = collection.personal_folder_type 

    if pf_type 
      nu_core_file.category = NuCoreFile.personal_folder_to_category(pf_type) 
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

      update_metadata_from_upload_screen(@nu_core_file, current_user, file, params[:collection_id])
      Sufia.queue.push(ContentCreationJob.new(@nu_core_file.pid, new_path.to_s, file.original_filename, current_user.id))
      @nu_core_file.record_version_committer(current_user)
      redirect_to NuCoreFilesController.upload_complete_path
    else
      render :json => [{:error => "Error creating generic file."}]
    end
  end

  def perform_local_ingest
      if Sufia.config.enable_local_ingest && current_user.respond_to?(:directory)
        if ingest_local_file
          redirect_to NuCoreFilesController.upload_complete_path
        else
          flash[:alert] = "Error importing files from user directory."
          render :new
        end
      else
        flash[:alert] = "Your account is not configured for importing files from a user-directory on the server."
        render :new
      end
    end

end