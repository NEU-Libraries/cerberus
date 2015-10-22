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
          render json: Zlib::Inflate.inflate(FileSizeGraph.last.json_values)
        rescue NoMethodError
          render json: ({"name" => "No file sizes yet", "size" => "0"}).to_json
        end
      end
    end
  end
end
