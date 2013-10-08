module DepartmentsHelper

  # Render a button for creating a new collection within this collection
  # if the current user has edit permissions. 
  def render_create_department_button(department_parent)
    if current_user_can_edit?(department_parent) 
      if request.original_fullpath == departments_path
        link_to("Create a child department off this node", new_department_path(:department_parent => Rails.configuration.root_department_id))
      else 
        link_to("Create a child department off this node", new_department_path(department_parent: department_parent.identifier))
      end  
    end
  end
end
