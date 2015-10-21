class FileSizeGraphJob
  def queue_name
    :file_size_graph
  end

  def run
    results_hsh = Hash.new
    results_hsh["name"] = "Northeastern University"

    neu_doc = SolrDocument.new(Community.find("neu:1").to_solr)

    total_results = populate(neu_doc)
    results_hsh["total"] = total_results["total"]
    results_hsh["children"] = total_results["results"]

    return results_hsh.to_json
  end

  def core_file_size(pid)
    cf_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{pid}\"").first

    all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                            "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                            "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                            "ZipFile", "AudioFile", "VideoFile" ]
    models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
    models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified

    content_objects = solr_query_file_size("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{full_pid(pid)}")

    total_size = 0
    content_objects.map{|doc| total_size += doc.file_size.to_i}

    return total_size
  end

  # -----

  def populate(parent_doc)
    children = []
    children.push(*child_sets(parent_doc.pid))
    children.push(*child_files(parent_doc.pid))

    return { "results" => [], "total" => 0 } if children.length == 0 # base case

    results = []
    total = 0

    children.each do |doc|
      if doc.klass == "CoreFile"
        x = Hash.new

        x["name"] = doc.title
        x["type"] = doc.klass
        x["pid"] = doc.pid
        x["size"] = core_file_size(doc.pid)

        total += x["size"].to_i
        results << x
      else
        x = Hash.new
        internal_results = populate(doc)

        x["name"] = doc.title
        x["type"] = doc.klass
        x["pid"] = doc.pid
        x["total"] = internal_results["total"].to_i
        x["children"] = internal_results["results"]

        total += x["total"].to_i
        results << x
      end
    end

    results_and_total = { "results" => results, "total" => total }

    return results_and_total
  end

  # -----

  def child_files(pid)
    core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
    solr_query_metadata("is_member_of_ssim:#{full_pid(pid)} AND has_model_ssim:#{core_file_model}")
  end

  def child_sets(pid)
    core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
    solr_query_metadata("has_affiliation_ssim:#{full_pid(pid)} OR is_member_of_ssim:#{full_pid(pid)} NOT has_model_ssim:#{core_file_model}")
  end

  # ------

  def solr_query_file_size(query_string)
    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :fl => "id file_size_tesim", :rows => row_count)
    return query_result.map { |x| SolrDocument.new(x) }
  end

  def solr_query_metadata(query_string)
    row_count = ActiveFedora::SolrService.count(query_string)
    query_result = ActiveFedora::SolrService.query(query_string, :fl => "id title_info_title_ssi active_fedora_model_ssi", :rows => row_count)
    return query_result.map { |x| SolrDocument.new(x) }
  end

  def full_pid(pid)
    return ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{pid}"
  end

end
