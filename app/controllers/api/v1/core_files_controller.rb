module Api
  module V1
    class CoreFilesController < ApplicationController

      def show
        begin
          @core_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        if @core_doc.blank? || !@core_doc.public?
          render json: {error: "The item you've requested is unavailable."} and return
        end

        result_hsh = fetch_core_hash

        render json: result_hsh.to_json
      end
    end
  end
end
