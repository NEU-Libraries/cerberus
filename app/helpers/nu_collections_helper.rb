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

  # Render a button for uploading files within this collection
  # if the current user has edit permissions.
  def render_upload_files_button(parent)
    if current_user_can_edit?(parent) && !(request.original_fullpath == nu_collections_path)
      link_to("Upload files to this collection", new_nu_core_file_path(parent: parent.identifier))
    end
  end

  # Render a button for creating a new collection within this collection
  # if the current user has edit permissions. 
  def render_create_collection_button(parent)
    if current_user_can_edit?(parent)
      link_to("Create a child collection off this node", new_nu_collection_path(parent: parent.identifier))
    end
  end

  # Render a button for deleting this object if the user 
  # has edit permissions over the object being deleted
  def render_delete_object_button(obj, delete_text) 
    if current_user_can_edit?(obj) 
      confirm_copy = "This destroys the object and all of its descendents.  Are you sure?" 
      link_to(delete_text, obj, method: :delete, confirm: confirm_copy) 
    end
  end
end
