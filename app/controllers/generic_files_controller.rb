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

class GenericFilesController < ApplicationController
  include Sufia::Controller
  include Sufia::FilesControllerBehavior

  skip_before_filter :normalize_identifier, only: [:provide_metadata, :rescue_incomplete_files, :destroy_incomplete_files, :process_metadata]
  skip_load_and_authorize_resource only: [:provide_metadata, :rescue_incomplete_files, :destroy_incomplete_files, :process_metadata] 
  def destroy_incomplete_files
    GenericFile.users_in_progress_files(current_user).each do |file|
      file.destroy 
    end

    redirect_to files_provide_metadata_path 
  end

  def provide_metadata
    @generic_file = GenericFile.new 
    @incomplete_files = GenericFile.users_in_progress_files(current_user) 
  end

  # routed to files/rescue_incomplete_files
  # page for allowing users to either permanently delete or apply metadata to 
  # files abandoned without completing step two of the upload process. 
  def rescue_incomplete_files
    file_titles = []

    request.query_parameters.each do |key, pid| 
      file_titles << GenericFile.find(pid).title
    end

    @incomplete_file_titles = file_titles 
  end

  def process_metadata
    Sufia.queue.push(MetadataUpdateJob.new(current_user.user_key, params))
    flash[:notice] = 'Your files are being processed by ' + t('sufia.product_name') + ' in the background. The metadata and access controls you specified are being applied. Files will be marked <span class="label label-important" title="Private">Private</span> until this process is complete (shouldn\'t take too long, hang in there!). You may need to refresh your dashboard to see these updates.'
    redirect_to sufia.dashboard_index_path    
  end

  # routed to /files/new
  def new
    in_progress_files = GenericFile.users_in_progress_files(current_user)

    if !in_progress_files.empty?

      param_hash = {}
      in_progress_files.each_with_index do |file, index| 
        param_hash = param_hash.merge({"file#{index}" => file.pid}) 
      end

      redirect_to rescue_incomplete_files_path(param_hash)
    end

    @generic_file = ::GenericFile.new
    #@batch_noid = Sufia::Noid.noidify(Sufia::IdService.mint)
    @collection_id = params[:parent]      
  end

  def self.upload_complete_path
    Rails.application.routes.url_helpers.files_provide_metadata_path
  end

  protected

  #Allows us to map different params 
  def update_metadata_from_upload_screen(generic_file)
    # Relative path is set by the jquery uploader when uploading a directory
    generic_file.relative_path = params[:relative_path] if params[:relative_path]
  end

  def process_file(file)
    if virus_check(file) == 0 
      @generic_file = ::GenericFile.new
      update_metadata_from_upload_screen(@generic_file) 
      #GenericFile.create_metadata(@generic_file, current_user, params[:batch_id], params[:collection_id])
      GenericFile.create_metadata(@generic_file, current_user, params[:collection_id])
      Sufia::GenericFile::Actions.create_content(@generic_file, file, file.original_filename, datastream_id, current_user)
      respond_to do |format|
        format.html {
          render :json => [@generic_file.to_jq_upload],
            :content_type => 'text/html',
            :layout => false
        }
        format.json {
          render :json => [@generic_file.to_jq_upload]
        }
      end
    else
      render :json => [{:error => "Error creating generic file."}]
    end
  end

  def perform_local_ingest
      if Sufia.config.enable_local_ingest && current_user.respond_to?(:directory)
        if ingest_local_file
          redirect_to GenericFilesController.upload_complete_path
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