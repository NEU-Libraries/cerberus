module CollectionsHelper

  # Removes the following from the permissions list
  # - The depositing user, who cannot have their edit privileges revoked through the frontend
  # - The group level permission for 'public' and 'registered' groups.
  def filtered_permissions(collection)
    perms = collection.permissions
    depositor = collection.depositor

    perms.select! { |coll| coll[:name] != depositor && coll[:name] != 'public' && coll[:name] != 'registered' && coll[:name] != '' && coll[:type] != 'user' && coll[:name] != 'northeastern:drs:repository:staff' }

    return perms
  end

  # Render a button for uploading files within this collection
  # if the current user has edit permissions.
  def render_upload_files_button(parent, text = "Upload files to this collection" , html_options = {} )
    if (current_user.can?(:edit, parent.pid) || current_user.proxy_staff? ) && !(request.original_fullpath == collections_path)
      link_to( text , new_core_file_path(parent: parent.pid), html_options )
    end
  end

  # Render a button for creating a new collection within this collection
  # if the current user has edit permissions.
  def render_create_collection_button(parent, text = "Create a child collection off this node" , html_options = {} )
    if (current_user.can?(:edit, parent.pid) || current_user.proxy_staff? )
      link_to(text, new_collection_path(parent: parent.pid), html_options)
    end
  end

  # Render a button for deleting this object if the user
  # has edit permissions over the object being deleted
  def render_delete_object_button(obj, delete_text)
    if (current_user.can? :edit, obj.pid )
      confirm_copy = "This destroys the object and all of its descendents.  Are you sure?"
      link_to(delete_text, obj, method: :delete, confirm: confirm_copy)
    end
  end
end
