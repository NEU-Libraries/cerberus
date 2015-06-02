module Api
  module V1
    class CoreFilesController < ApplicationController
      include ModsDisplay::ControllerExtension

      def show
        @core_file = ActiveFedora::Base.find(params[:id], cast: true)
        @core_doc = SolrDocument.new(@core_file.to_solr)
        mods_json = render_mods_display(@core_file).to_json
        result_hsh = Hash.new
        result_hsh["pid"] = @core_file.pid
        result_hsh["thumbnails"] = @core_doc.thumbnail_list.map { |url_string| "#{root_path(:only_path => false)}#{url_string.sub!(/^\//, '')}"}
        result_hsh["canonical_object"] = @core_doc.canonical_object.map { |doc| doc_to_url(doc) }
        result_hsh["content_objects"] = @core_doc.content_objects.map { |doc| doc_to_url(doc) }
        result_hsh["mods"] = JSON.parse(mods_json)
        render json: result_hsh.to_json
      end

      protected
        def doc_to_url(solr_doc)
          return download_path(solr_doc.pid, :only_path => false)
        end
    end
  end
end
