class NuCollectionsController < ApplicationController
  def index
  end

  def new
    @nu_collection = NuCollection.new
  end

  def create
    #render text: params[:nu_collection].inspect
    @nu_collection = NuCollection.new
    @nu_collection.nu_title = params[:nu_collection][:nu_title]
    @nu_collection.nu_description = params[:nu_collection][:nu_description]
    @nu_collection.save!
    redirect_to(@nu_collection, :notice => 'Collection was successfully created.')
  end

end
