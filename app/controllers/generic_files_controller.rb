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

  # routed to /files/new
  def new
    @generic_file = ::GenericFile.new
    @batch_noid = Sufia::Noid.noidify(Sufia::IdService.mint)
    @collection_id = params[:parent]      
  end

  protected 

  #Allows us to map different params 
  def update_metadata_from_upload_screen(generic_file)
    # Relative path is set by the jquery uploader when uploading a directory
    generic_file.relative_path = params[:relative_path] if params[:relative_path]  
    generic_file.crud.mass_add_perm('individual', current_user.to_s, [:create, :read, :update, :delete]) 
  end

  def process_file(file)
    if virus_check(file) == 0 
      @generic_file = ::GenericFile.new
      update_metadata_from_upload_screen(@generic_file) 
      GenericFile.create_metadata(@generic_file, current_user, params[:batch_id], params[:collection_id])
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

end