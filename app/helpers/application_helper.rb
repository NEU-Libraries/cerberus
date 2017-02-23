module ApplicationHelper
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

  def kramdown_parse(input_str)
    return "" unless input_str
    input_str = input_str.gsub("--", "&#45;&#45;")
    output_str = Unidecoder.decode(Sanitize.clean(Kramdown::Document.new(input_str).to_html, :elements => ['sup', 'sub']))
    output_str = output_str.strip
    return output_str.html_safe
  end

  def breadcrumb_to_root(obj, breadcrumb = [])
    if breadcrumb.empty?
      title_str = CGI::unescapeHTML kramdown_parse(obj.title)
      breadcrumb << content_tag(:li, title_str.html_safe, class: 'active')
    end
    if !obj.respond_to?(:parent) || obj.parent.nil?
      return breadcrumb.reverse
    else
      if obj.parent.is_a?(String)
        parent = solr_query("id:\"#{obj.parent}\"").first
      else
        parent = solr_query("id:\"#{obj.parent.pid}\"").first
      end
      breadcrumb << content_tag(:li, link_to(kramdown_parse(parent.title).html_safe, polymorphic_path(parent)))
      breadcrumb_to_root(parent, breadcrumb)
    end
  end
end
