class Admin::CommunitiesController < AdminController

  # Loads @community for each action type
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
      redirect_to community_path(id: @community.identifier) and return  
    else
      flash.now[:error] = "Something went wrong"
      redirect_to new_community_path(parent: params[:parent]) and return 
    end
  end
end
