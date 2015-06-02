module Api
  module V1
    class CoreFilesController < ApplicationController

      def show
        @core_file = ActiveFedora::Base.find(params[:id], cast: true)

        if !(SolrDocument.new(@core_file.to_solr)).public?
          render json: {error: "The item you've requested is unavailable."} and return
        end

        result_hsh = @core_file.to_hash
        render json: result_hsh.to_json
      end
    end
  end
end
