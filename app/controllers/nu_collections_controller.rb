class NuCollectionsController < ApplicationController
  def index
  end

  def new
    if !current_user 
      redirect_to('/') 
    else 
      @nu_collection = NuCollection.new    
    end
  end

  def create
    #render text: params[:nu_collection].inspect
    @nu_collection = NuCollection.new

    #to get a correct pid
    @nu_collection.save!

    # DC stream
    @nu_collection.nu_title = params[:nu_collection][:nu_title]
    @nu_collection.nu_description = params[:nu_collection][:nu_description]
    @nu_collection.nu_identifier = @nu_collection.id

    # MODS stream
    @nu_collection.create_mods_stream(params)

    # Permission concerns
    @nu_collection.rightsMetadata.embargo_release_date = params[:nu_collection][:embargo_date] 
    @nu_collection.depositor = current_user.nuid
    @nu_collection.rightsMetadata.permissions({person: current_user.nuid}, 'edit')

    # Extract from the form all keys of form 'permissions#{n}' 
    # ex. 'permissions1' => { 'identity_type' => 'group', 'identity' => 'public', 'permission_type' => 'read' } 
    all_perms = params[:nu_collection].select { |key, value| key.include?('permissions') } 
    @nu_collection.set_permissions_from_new_form(all_perms) 

    if params[:nu_collection][:pid].present?
      @nu_collection.add_relationship("isPartOf", "info:fedora/#{Sufia::Noid.namespaceize(params[:nu_collection][:pid])}")
    elsif @nu_collection.pid != '1'
      raise "New collections must have a parent."
    end

    @nu_collection.save!
    redirect_to(@nu_collection, :notice => 'Collection was successfully created.')
  end

  def index
    if ! current_user 
      redirect_to('/') 
    else 
      @all_collections = NuCollection.find_all_viewable(current_user) 
    end
  end

  def show  
    @nu_collection = NuCollection.find(params[:id]) 
  end

  def edit
    @nu_collection = NuCollection.find(params[:id]) 
  end
end
