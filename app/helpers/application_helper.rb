module ApplicationHelper

  # Only things with theoretically near universal potential use should go here.

  def not_a_bot?
    # basic method to try and prevent bots getting lost in facet infinite space
    if !request.blank?
      ua = request.user_agent
      botlist = I18n.t("bots").map(&:downcase)
      if botlist.any?{|s| ua.include?(s)}
        return false
      end
    end

    return true
  end

  def invalidate_cache(pattern)
    cursor = "0"
    batch_size = 1000
    begin
      $redis.auth(ENV["REDIS_PASSWD"])
      cursor, keys = $redis.scan(cursor, match: pattern, count: batch_size)
      $redis.del(*keys) unless keys.empty?
    end until cursor == "0"
  end

  def invalidate_pid(pid)
    invalidate_cache("/mods/#{pid}*")
    invalidate_cache("/darwin/#{pid}*")
    invalidate_cache("/content_objects/#{pid}*")
  end

  def solr_query(query_string, pid_only = false)
    # By default, SolrService.query only returns 10 rows
    # You can specify more rows than you need, but not just to return all results
    # This is a small helper method that combines SolrService's count and query to
    # get back all results, without guessing at an upper limit
    row_count = ActiveFedora::SolrService.count(query_string)
    if pid_only
      query_result = ActiveFedora::SolrService.query(query_string, :rows => row_count, :fl => "id")
    else
      query_result = ActiveFedora::SolrService.query(query_string, :rows => row_count)
    end
    return query_result.map { |x| SolrDocument.new(x) }
  end

  def cached_content_objects(core_file)
    Rails.cache.fetch("/content_objects/#{core_file.pid}-#{core_file.updated_at}", :expires_in => 5.days) do
      core_file.content_objects_sorted
    end
  end

  def kramdown_parse(input_str)
    return "" unless input_str
    input_str = input_str.gsub("--", "&#45;&#45;")
    output_str = Unidecoder.decode(Sanitize.clean(Kramdown::Document.new(input_str).to_html, :elements => ['sup', 'sub']))
    output_str = output_str.strip
    return output_str.html_safe
  end

  def xml_decode(input_str)
    return "" unless input_str
    # scrub all html hex codes that arent & < or >.
    # RADS either deliberately, or copy and pasted,
    # smart quotes &#8220; andd #8221;
    # up to 5 chars either side of a mid-char of # seems to be the most effective without causing issues.
    escaped_val = input_str.gsub(/(&)(.{0,5})[#?](.{0,5})(;)/) { |m| (["&amp;","&lt;","&gt;", "&amp;amp;", "&amp;lt;", "&amp;gt;"].include? m) ? m : "" }
    escaped_val = escaped_val.gsub("&amp;", "&amp;amp;")
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

    if !set.respond_to?(:parent) || set.parent.nil?
      return breadcrumb.reverse
    else
      if set.parent.is_a?(String)
        parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{set.parent}\"").first)
      else
        parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{set.parent.pid}\"").first)
      end
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

  def page_file_breadcrumb_to_root(page_file, core_pid, breadcrumb = [])
    if breadcrumb.empty?
      title_str = "#{I18n.t("drs.display_labels.PageFile.short")} #{page_file.ordinal_value}"
      breadcrumb << content_tag(:li, title_str.html_safe, class: 'active')
    end
    parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{core_pid}\"").first)
    breadcrumb << content_tag(:li, link_to(kramdown_parse(parent.title).html_safe, polymorphic_path(parent)))
    breadcrumb_to_root(parent, breadcrumb)
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

  def drs_per_page
    if current_user
      if !current_user.per_page_pref
        current_user.per_page_pref = '10'
        current_user.save!
      end
      user_view_pref = current_user.per_page_pref
    else
      if !session[:per_page_pref]
        session[:per_page_pref] = '10'
      end
      user_view_pref = session[:per_page_pref]
    end
    if params.has_key?(:per_page) && (user_view_pref != params[:per_page])
      user_view_pref = params[:per_page]
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
