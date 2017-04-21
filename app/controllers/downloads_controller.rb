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
    if !params[:file].blank?
      file_reference = params[:file]
      obj = ActiveFedora::Base.find(params[asset_param_key])
      obj.send file_reference
    else
      # After three years of watching bots fail to figure out basic arguments
      # because script kiddies can't scrape properly, I think we just send them
      # to the void with a 500. Don't send error emails, it's never a real
      # person with an honest mistake.
      render :nothing => true, :status => 500, :content_type => 'text/html' and return
    end
  end
end
