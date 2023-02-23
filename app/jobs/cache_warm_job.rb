class CacheWarmJob
  include ApplicationHelper

  def queue_name
    :cache_warm
  end

  def run
    # expire cache
    invalidate_cache("/smart_collections/*")
    # solr query all communities
    model_type = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Community"
    query = "has_model_ssim:\"#{model_type}\""
    row_count = ActiveFedora::SolrService.count(query)
    query_result = ActiveFedora::SolrService.query(query, :fl => "id", :rows => row_count)
    # loop and warm cache for slow smart_collections query
    query_result.each do |hsh|
      pid = hsh["id"]
      community = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      Rails.cache.fetch("/smart_collections/#{community.pid}-#{community.find_employees.count}}", :expires_in => 1.day) do
        community.smart_collections # super slow query
      end
    end
  end

end
