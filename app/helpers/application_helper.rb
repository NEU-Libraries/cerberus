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

  # Generates an array of link/li tags that should breadcrumb back to the Root Collection  
  def breadcrumb_to_root(set, breadcrumb = [])    
    if breadcrumb.empty? 
      breadcrumb << content_tag(:li, set.title, class: 'active')  
    end
        
    if set.parent.nil?
      return breadcrumb.reverse
    else
      breadcrumb << content_tag(:li, link_to(set.parent.title, set))
      if set.parent.nil?
        breadcrumb_to_root(set.parent, breadcrumb)
      end        
    end
  end  
end