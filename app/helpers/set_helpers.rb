module SetHelpers
  # Convenience methods for fetching every child object 
  # that the current user can read. 
  def readable_child_files(set) 
    return set.child_files.keep_if { |f| current_user_can_read? f } 
  end

  def readable_child_collections(set)
    return set.child_collections.keep_if { |c| current_user_can_read? c }
  end

  def readable_child_communities(set)
    return set.child_communities.keep_if { |c| current_user_can_read? c } 
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