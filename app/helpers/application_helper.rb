module ApplicationHelper

  # Only things with theoretically near universal potential use should go here.

  def thumbnail_for(core_record) 
    if core_record.thumbnail 
      return core_record.thumbnail 
    else
      return core_record.canonical.class.to_s
    end
  end

  # Determine whether or not the viewing user can read this object
  def current_user_can_read?(fedora_object) 
    return fedora_object.rightsMetadata.can_read?(current_user) 
  end

  # Determine whether or not the viewing user can edit this object
  def current_user_can_edit?(fedora_object) 
    return fedora_object.rightsMetadata.can_edit?(current_user)  
  end
end