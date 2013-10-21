module CommunitiesHelper

  # Render a button for creating a new collection within this collection
  # if the current user has edit permissions. 
  def render_create_community_button(parent)
    if current_user_can_edit?(parent) 
      if request.original_fullpath == communities_path # Handle the case where a community is being created off root. 
        link_to("Create a child community off this node", new_community_path(parent: Rails.configuration.root_community_id))
      else 
        link_to("Create a child community off this node", new_community_path(parent: parent.identifier))
      end  
    end
  end
end
