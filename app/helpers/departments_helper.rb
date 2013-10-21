module CommunitiesHelper

  # Render a button for creating a new collection within this collection
  # if the current user has edit permissions. 
  def render_create_department_button(parent)
    if current_user_can_edit?(parent) 
      if request.original_fullpath == departments_path # Handle the case where a department is being created off root. 
        link_to("Create a child department off this node", new_department_path(parent: Rails.configuration.root_department_id))
      else 
        link_to("Create a child department off this node", new_department_path(parent: parent.identifier))
      end  
    end
  end
end
