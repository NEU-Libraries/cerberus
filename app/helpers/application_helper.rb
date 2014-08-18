module ApplicationHelper

  # Only things with theoretically near universal potential use should go here.

  def kramdown_parse(input_str)
    return "" unless input_str
    output_str = Sanitize.clean(Kramdown::Document.new(input_str).to_html, :elements => ['sup', 'sub'])
    output_str = output_str.strip
    return output_str.html_safe
  end

  def title_string(page_title)
    if page_title.blank?
      return "DRS"
    else
      kramdown_parse("#{page_title} - DRS")
    end
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
      title_str = CGI::unescapeHTML "#{set.non_sort} #{kramdown_parse(set.title)}"
      breadcrumb << content_tag(:li, title_str, class: 'active')
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
        current_user.view_pref = 'list'
        current_user.save!
      end
      user_view_pref = current_user.view_pref
    else
      if !session[:view_pref]
        session[:view_pref] = 'list'
      end
      user_view_pref = session[:view_pref]
    end
    return user_view_pref
  end

end
