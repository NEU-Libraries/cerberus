class DownloadsController < ApplicationController
  include Hydra::Controller::DownloadBehavior

  def authorize_download!
    authorize! :read, params[asset_param_key]
  rescue CanCan::AccessDenied
    # redirect to 404 TODO
  end

  def load_file
    # Hydra Works puts things in containers, requiring an overload of this method
    # instead of sub_resource "datastreams", we have file sets with files attached
    # Fair to assume that asset_param_key will always be a file set id
    # and :file will always be the datastream label
    file_reference = params[:file]
    obj = ActiveFedora::Base.find(params[asset_param_key])
    obj.send file_reference
  end
end
