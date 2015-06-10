module Cerberus
  module CoreFile
    module ExtractValues

      def to_hash
        @core_doc = SolrDocument.new(self.to_solr)
        mods_json = fetch_mods_json
        result_hsh = Hash.new
        result_hsh["pid"] = self.pid
        result_hsh["parent"] = @core_doc.parent
        result_hsh["thumbnails"] = @core_doc.thumbnail_list.map { |url_string| "#{root_path(:only_path => false)}#{url_string.sub!(/^\//, '')}"}
        result_hsh["canonical_object"] = @core_doc.canonical_object.map { |doc| [doc_to_url(doc), doc.derivative_label] }
        result_hsh["content_objects"] = @core_doc.content_objects.map { |doc| [doc_to_url(doc), doc.derivative_label] }
        result_hsh["mods"] = JSON.parse(mods_json)
        return result_hsh
      end

      protected
        def doc_to_url(solr_doc)
          return download_path(solr_doc.pid, :only_path => false)
        end

        def fetch_mods_json
          CoreFilesController.new.render_mods_display(self).to_json
        end
    end
  end
end
