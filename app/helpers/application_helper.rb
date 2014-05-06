module ApplicationHelper

  # Only things with theoretically near universal potential use should go here.

  def kramdown_parse(input_str)
    return "" unless input_str
    return Sanitize.clean(Kramdown::Document.new(input_str).to_html, :elements => ['sup', 'sub']).html_safe
  end

  def thumbnail_for(core_record)
    if core_record.thumbnail
      return core_record.thumbnail
    else
      return core_record.canonical.class.to_s
    end
  end

  # Generates an array of link/li tags that should breadcrumb back to the Root Collection
  def breadcrumb_to_root(set, breadcrumb = [])
    if breadcrumb.empty?
      breadcrumb << content_tag(:li, kramdown_parse(set.title), class: 'active')
    end

    if set.parent.nil?
      return breadcrumb.reverse
    else
      parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first)
      breadcrumb << content_tag(:li, link_to(kramdown_parse(parent.title), polymorphic_path(parent)))
      breadcrumb_to_root(parent, breadcrumb)
    end
  end

  # Generates an array of link/li tags that should breadcrumb back to the Root Collection from a Smart Collection
  def smart_collection_breadcrumb(set, breadcrumb = [])
    if breadcrumb.empty?
      breadcrumb << content_tag(:li, link_to(kramdown_parse(set.title), polymorphic_path(set)))
    end

    if set.parent.nil?
      return breadcrumb.reverse
    else
      parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first)
      breadcrumb << content_tag(:li, link_to(kramdown_parse(parent.title), polymorphic_path(parent)))
      breadcrumb_to_root(parent, breadcrumb)
    end
  end

  # Helper method to either the preference of user or session variable for a guest
  def drs_view_class
    if current_user
      if !current_user.view_pref
        current_user.view_pref == 'grid'
        current_user.save!
      end
      user_view_pref = current_user.view_pref
    else
      if !session[:view_pref]
        session[:view_pref] == 'grid'
      end
      user_view_pref = session[:view_pref]
    end
    return user_view_pref == "grid" ? "drs-items-grid" : "drs-items-list"
  end

end
