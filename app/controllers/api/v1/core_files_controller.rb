module Api
  module V1
    class CoreFilesController < ApplicationController

      def show
        @core_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first

        if @core_doc.blank? || !@core_doc.public?
          render json: {error: "The item you've requested is unavailable."} and return
        end

        result_hsh = fetch_core_hash

        render json: result_hsh.to_json
      end
    end
  end
end
