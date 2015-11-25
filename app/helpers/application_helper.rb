module ApplicationHelper

  # Only things with theoretically near universal potential use should go here.

  def solr_query(query_string)
    # By default, SolrService.query only returns 10 rows
    # You can specify more rows than you need, but not just to return all results
    # This is a small helper method that combines SolrService's count and query to
    # get back all results, without guessing at an upper limit
    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :rows => row_count)
    return query_result.map { |x| SolrDocument.new(x) }
  end

  def cached_content_objects(core_file)
    Rails.cache.fetch("/content_objects/#{core_file.pid}-#{core_file.updated_at}", :expires_in => 12.hours) do
      core_file.content_objects_sorted
    end
  end

  def kramdown_parse(input_str)
    return "" unless input_str
    output_str = Unidecoder.decode(Sanitize.clean(Kramdown::Document.new(input_str).to_html, :elements => ['sup', 'sub']))
    output_str = output_str.strip
    return output_str.html_safe
  end

  def xml_decode(input_str)
    escaped_val = input_str.gsub("&amp;", "&amp;amp;")
    escaped_val = escaped_val.gsub("&lt;", "&amp;lt;")
    escaped_val = escaped_val.gsub("&gt;", "&amp;gt;")
    CGI.unescapeHTML(Unidecoder.decode(escaped_val))
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
      breadcrumb << content_tag(:li, title_str.html_safe, class: 'active')
    end

    if set.parent.nil?
      return breadcrumb.reverse
    else
      parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first)
      breadcrumb << content_tag(:li, link_to(kramdown_parse(parent.title).html_safe, polymorphic_path(parent)))
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

  def set_breadcrumb_to_root(set, breadcrumb = [])
    if breadcrumb.empty?
      breadcrumb << content_tag(:li, params[:action].humanize.titleize, class: 'active')
    end
    if breadcrumb.length == 1
      title_str = CGI::unescapeHTML "#{set.non_sort} #{kramdown_parse(set.title)}"
      breadcrumb << content_tag(:li, link_to(title_str.html_safe, polymorphic_path(set)))
    end

    if set.parent.nil?
      return breadcrumb.reverse
    else
      parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first)
      breadcrumb << content_tag(:li, link_to(kramdown_parse(parent.title).html_safe, polymorphic_path(parent)))
      breadcrumb_to_root(parent, breadcrumb)
    end
  end

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

  def sortable(column, title = nil)
    title ||= column.titleize
    css_class = column == sort_column ? "current #{sort_direction}" : nil
    direction = column == sort_column && sort_direction == "asc" ? "desc" : "asc"
    link_to "#{title} <span class='icon-small'></span>".html_safe, {:sort => column, :direction => direction}, {:class => css_class}
  end

end
