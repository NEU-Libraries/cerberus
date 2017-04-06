module Api
  module V1
    class CoreFilesController < ApplicationController

      def show
        begin
          @core_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        if @core_doc.blank?         ||
            !@core_doc.public?      ||
            @core_doc.in_progress?  ||
            @core_doc.incomplete?   ||
            @core_doc.embargo_date_in_effect?
          render json: {error: "The item you've requested is unavailable."} and return
        end

        result_hsh = fetch_core_hash

        render json: result_hsh.to_json
      end

      def file_sizes
        begin
          # render json: Zlib::Inflate.inflate(Base64.decode64(FileSizeGraph.last.json_values))
          render json: FileSizeGraph.last.json_values
        rescue NoMethodError
          render json: ({"name" => "No file sizes yet", "size" => "0"}).to_json
        end
      end

      def content_objects
        begin
          result_hsh = Hash.new

          core_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first

          result_hsh["canonical_object"] = core_doc.canonical_object.map { |doc| {doc_to_url(doc) => doc.derivative_label} }.reduce(&:merge)
          result_hsh["content_objects"] = core_doc.content_objects.map { |doc| {doc_to_url(doc) => doc.derivative_label} }.reduce(&:merge)

          render json: result_hsh.to_json
        rescue NoMethodError
          render json: {error: "This item has no content objects."} and return
        end
      end

      protected
        def doc_to_url(solr_doc)
          return download_path(solr_doc.pid, :only_path => false)
        end
        
    end
  end
end
