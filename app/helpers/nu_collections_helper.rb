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

  # Generates an array of link/li tags that should breadcrumb back to the Root Collection  
  def breadcrumb_to_root(collection, breadcrumb = [])  
    if collection.parent.nil?
      return breadcrumb.reverse
    else
      if breadcrumb.empty? 
        breadcrumb << content_tag(:li, collection.title, class: 'active')  
      end
      breadcrumb << link_to(collection.parent.title, nu_collection_path(collection.parent.identifier))
      breadcrumb_to_root(collection.parent, breadcrumb)  
    end
  end

  # Determine whether or not the viewing user can read this collection
  def current_user_can_read?(collection) 
    return collection.rightsMetadata.can_read?(current_user) 
  end

  # Determine whether or not the viewing user can edit this collection 
  def current_user_can_edit?(collection) 
    return collection.rightsMetadata.can_edit?(current_user)  
  end

  # Render a button for creating a new collection within this collection
  # if the current user has edit permissions. 
  def render_create_collection_button(parent)
    if current_user_can_edit?(parent) 
      if request.original_fullpath == nu_collections_path
        link_to("Create a child collection off this node", new_nu_collection_path(:parent => Rails.configuration.root_collection_id))
      else 
        link_to("Create a child collection off this node", new_nu_collection_path(parent: parent.identifier))
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
