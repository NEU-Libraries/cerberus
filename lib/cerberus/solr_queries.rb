module Cerberus
  module SolrQueries

    def all_descendent_files
      result = []
      each_depth_first do |child|
        if(child.klass == "Collection")
          result += child.child_files
        end
      end
      return result
    end

    def supplemental_materials
      # solr query for items that have the correct rels_ext connection to this core file
      children_query_result = ActiveFedora::SolrService.query("is_supplemental_material_for_ssim:#{self.full_self_id}")
      children_query_result.map { |x| SolrDocument.new(x) }
    end

    def child_files
      core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
      children_query_result = ActiveFedora::SolrService.query("is_member_of_ssim:#{self.full_self_id} AND has_model_ssim:#{core_file_model}")
      children_query_result.map { |x| SolrDocument.new(x) }
    end

    def combined_set_children
      core_file_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:CoreFile"
      combined_children_query_result = ActiveFedora::SolrService.query("has_affiliation_ssim:#{self.full_self_id} OR is_member_of_ssim:#{self.full_self_id} NOT has_model_ssim:#{core_file_model}")
      combined_children_query_result.map { |x| SolrDocument.new(x) }
    end

    def combined_set_descendents
      descendents = self.combined_set_children
      descendents.each do |set|
        descendents.concat set.combined_set_children
      end
      return descendents
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
      query_result = ActiveFedora::SolrService.query("canonical_tesim:yes AND is_part_of_ssim:#{self.full_self_id}")
      docs = query_result.map { |x| SolrDocument.new(x) }
    end

    def content_objects
      all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                              "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                              "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                              "ZipFile", "AudioFile", "VideoFile" ]
      models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
      models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified

      query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{self.full_self_id}")

      docs = query_result.map { |x| SolrDocument.new(x) }
    end

    # Imposes an arbitrary but aesthetically pleasing order on returned images
    def content_objects_sorted
      co = content_objects

      sorter_proc = Proc.new do |klasses, arry|
        klasses.each do |klass|
          arry << co.find { |x| x.klass == klass }
        end

        arry.keep_if { |x| x.class == SolrDocument }
        return arry
      end

      if co.any? { |x| x.klass == "ImageMasterFile" }
        a = ["ImageSmallFile", "ImageMediumFile", "ImageLargeFile", "ImageMasterFile"]
        sorter_proc.call(a, [])
      else
        return co
      end
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
        doc_list.concat c.first.all_descendent_files
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

    def datasets
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
      end
      if self.datasets.length > 0
        smart_collection_list << "datasets"
      end
      if self.presentations.length > 0
        smart_collection_list << "presentations"
      end
      # if self.learning_objects.length > 0
      #   smart_collection_list << "learning"
      # end
      if self.other_publications.length > 0
        smart_collection_list << "other"
      end

      if smart_collection_list.length > 0
        smart_collection_list << "employees"
      end

      return smart_collection_list
    end

    def user_root_collection
      if self.klass == "Employee"
        collection_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Collection"
        root_collection_result = ActiveFedora::SolrService.query("is_member_of_ssim:#{self.full_self_id} AND has_model_ssim:#{collection_model} AND smart_collection_type_tesim:\"User Root\"")
        return SolrDocument.new(root_collection_result.first)
      end
    end

    def user_smart_collections
      if self.klass == "Employee"
        smart_collection_list = []

        urc = self.user_root_collection
        csc = urc.combined_set_children

        csc.each do |set|
          # Temporary, until we get Learning Objects sorted out
          if !set.smart_collection_type.nil? && set.smart_collection_type != "miscellany" && set.smart_collection_type != "Learning Objects"
            smart_collection_list << set
          end
        end
        return smart_collection_list
      end
    end

    def user_personal_collections
      if self.klass == "Employee"
        personal_collection_list = []

        urc = self.user_root_collection
        csc = urc.combined_set_children

        csc.each do |set|
          if set.smart_collection_type == "miscellany"
            personal_collection_list << set
          end
        end
        return personal_collection_list
      end
    end

    def codebooks
      return associated_files_by_type("is_codebook_for_ssim")
    end

    def datasets
      return associated_files_by_type("is_dataset_for_ssim")
    end

    def figures
      return associated_files_by_type("is_figure_for_ssim")
    end

    def instructional_materials
      return associated_files_by_type("is_instructional_material_for_ssim")
    end

    def supplemental_materials
      return associated_files_by_type("is_supplemental_material_for_ssim")
    end

    def transcriptions
      return associated_files_by_type("is_transcription_of_ssim")
    end

    def associated_files_by_type(relation)
      str = "info:fedora/#{self.pid}"
      r = ActiveFedora::SolrService.query("#{relation}:\"#{str}\"")
      r.map { |x| SolrDocument.new(x) }
    end
  end
end
