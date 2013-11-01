class Admin::CommunitiesController < AdminController

  # Loads @community
  load_resource

  def new 

  end

  def create
    @community = Community.new(params[:community].merge(pid: mint_unique_pid))

    @community.mass_permissions = 'public'
    @community.rightsMetadata.permissions({person: "#{current_user.nuid}"}, 'edit')

    @community.identifier = @community.pid

    if @community.save!
      flash[:info] = "Community created successfully."
      redirect_to admin_community_path(id: @community.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to admin_community_path(parent: params[:parent]) and return 
    end
  end

  def edit 
    
  end

  def update 
    if @community.update_attributes(params[:community])
      flash[:notice] =  "Community #{@community.title} was updated successfully."
      redirect_to admin_communities_path
    else
      flash[:notice] = "Community #{@community.title} failed to update."
      redirect_to admin_communities_path
    end 
  end
end