class ThumbnailsController < ApplicationController
  def show
    doc = SolrDocument.new ActiveFedora::SolrService.get("id:\"#{params[:id]}}\"")
  end
end
