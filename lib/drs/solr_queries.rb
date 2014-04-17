module Drs
  module SolrQueries

    def all_descendent_files
      result = []
      each_depth_first do |child|
        if(child.klass == "NuCollection")
          result += child.child_files
        end
      end
      return result
    end

    def child_files
      core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:NuCoreFile"
      children_query_result = ActiveFedora::SolrService.query("is_member_of_ssim:#{self.full_self_id} AND has_model_ssim:#{core_file_model}")
      children_query_result.map { |x| SolrDocument.new(x) }
    end

    def combined_set_children
      core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:NuCoreFile"
      combined_children_query_result = ActiveFedora::SolrService.query("has_affiliation_ssim:#{self.full_self_id} OR is_member_of_ssim:#{full_self_id} NOT has_model_ssim:#{core_file_model}")
      combined_children_query_result.map { |x| SolrDocument.new(x) }
    end

    def each_depth_first
      self.combined_set_children.each do |child|
        child.each_depth_first do |c|
          yield c
        end
      end

      yield self
    end

    def canonical_object
      self.content_objects(true).first
    end

    def content_objects(canonical = false)
      all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                              "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                              "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                              "ZipFile", "AudioFile", "VideoFile" ]
      models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
      models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified

      if canonical
        query_result = ActiveFedora::SolrService.query("canonical_tesim:yes AND is_part_of_ssim:#{self.full_self_id}", rows: 999)
      else
        query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{self.full_self_id}", rows: 999)
      end

      docs = query_result.map { |x| SolrDocument.new(x) }
    end

    def full_self_id
      full_self_id = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{self.pid}"
    end

    def find_employees
      employee_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Employee"
      query_result = ActiveFedora::SolrService.query("has_affiliation_ssim:\"#{self.full_self_id}\" AND has_model_ssim:\"#{employee_model}\"")
      query_result.map { |x| SolrDocument.new(x) }
    end

    def find_user_root_collections
      doc_list ||= []
      employee_list = find_employees
      employee_list.each do |e|
        full_employee_id = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{e.pid}"
        query_result = ActiveFedora::SolrService.query("is_member_of_ssim:\"#{full_employee_id}\" AND smart_collection_type_tesim:\"User Root\"")
        doc_list << query_result.map { |x| SolrDocument.new(x) }
      end
      return doc_list
    end

    def find_smart_collections_by_type(type_str)
      doc_list ||= []
      user_root_list = find_user_root_collections
      user_root_list.each do |r|
        query_result = ActiveFedora::SolrService.query("parent_id_tesim:\"#{r.first.pid}\" AND smart_collection_type_tesim:\"#{type_str}\"")
        doc_list << query_result.map { |x| SolrDocument.new(x) }
      end
      return doc_list
    end

    def find_all_files_by_type(type_str)
      doc_list ||= []
      cols = find_smart_collections_by_type(type_str)
      cols.each do |c|
        doc_list << c.first.all_descendent_files
      end
      return doc_list
    end

    def theses
      find_all_files_by_type("Theses and Dissertations")
    end

    def research_publications
      find_all_files_by_type("Research Publications")
    end

    def other_publications
      find_all_files_by_type("Other Publications")
    end

    def data_sets
      find_all_files_by_type("Datasets")
    end

    def presentations
      find_all_files_by_type("Presentations")
    end

    def learning_objects
      find_all_files_by_type("Learning Objects")
    end

    def smart_collections
      smart_collection_list ||= []
      if self.research_publications.length > 0
        smart_collection_list << "research"
      elsif self.data_sets.length > 0
        smart_collection_list << "datasets"
      elsif self.presentations.length > 0
        smart_collection_list << "presentations"
      elsif self.learning_objects.length > 0
        smart_collection_list << "learning"
      elsif self.other_publications.length > 0
        smart_collection_list << "other"
      end
      return smart_collection_list
    end

  end
end
