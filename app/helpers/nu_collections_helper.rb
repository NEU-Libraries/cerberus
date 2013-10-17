module NuCollectionsHelper

  # Removes the following from the permissions list
  # - The depositing user, who cannot have their edit privileges revoked through the frontend 
  # - The group level permission for 'public' and 'registered' groups.  
  def filtered_permissions(collection)
    perms = collection.permissions
    depositor = collection.depositor

    perms.select! { |coll| coll[:name] != depositor && coll[:name] != 'public' && coll[:name] != 'registered' } 

    return perms 
  end

  # Render a button for creating a new collection within this collection
  # if the current user has edit permissions. 
  def render_create_collection_button(parent)
    if current_user_can_edit?(parent) 
      if request.original_fullpath == departments_path
        link_to("Create a child collection off this node", new_nu_collection_path(:department_parent => Rails.configuration.root_department_id))
      else
        if parent.instance_of?(NuCollection)
          link_to("Create a child collection off this node", new_nu_collection_path(parent: parent.identifier))
        else
          link_to("Create a child collection off this node", new_nu_collection_path(department_parent: parent.identifier))
        end
      end  
    end
  end

  # Render a button for uploading files within this collection 
  # if the current user has edit permissions. 
  def render_upload_files_button(parent)
    if current_user_can_edit?(parent) && !(request.original_fullpath == nu_collections_path) 
      link_to("Upload files to this collection", new_nu_core_file_path(parent: parent.identifier)) 
    end
  end
end
