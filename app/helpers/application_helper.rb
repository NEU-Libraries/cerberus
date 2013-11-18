module ApplicationHelper

  # Only things with theoretically near universal potential use should go here.

  def thumbnail_for(core_record) 
    if core_record.thumbnail 
      return core_record.thumbnail 
    else
      return core_record.canonical.class.to_s
    end
  end
  
  # Return a string for NuCollections or Communities, will return the class otherwise.
  def get_set_class_label(set)
    if set.instance_of?(Community)
      return "Community"
    elsif set.instance_of?(NuCollection)
      return "Collection"
    else
      return set.class
    end
  end

  # Generates an array of link/li tags that should breadcrumb back to the Root Collection  
  def breadcrumb_to_root(set, breadcrumb = [])    
    if breadcrumb.empty? 
      breadcrumb << content_tag(:li, set.title, class: 'active')  
    end

    if set.parent.nil?
      return breadcrumb.reverse
    else
      # This is a giant kludge, for some reason neu:1 gets an id param tacked on if done the regular way
      breadcrumb << content_tag(:li, link_to(set.parent.title, polymorphic_path(set.parent).split('?')[0]))
      breadcrumb_to_root(set.parent, breadcrumb)
    end
  end  
end