module Api
  module V1
    class CoreFilesController < ApplicationController

      def show
        @core_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first

        if !@core_doc.public?
          render json: {error: "The item you've requested is unavailable."} and return
        end

        result_hsh = Hash.new

        if !Rails.cache.exist?("/api/#{@core_doc.pid}-#{@core_doc.updated_at}")
          @core_file = ActiveFedora::Base.find(params[:id], cast: true)
          result_hsh = @core_file.to_hash
        else
          result_hsh = Rails.cache.fetch("/api/#{@core_doc.pid}-#{@core_doc.updated_at}")
        end

        result_hsh = @core_file.to_hash
        render json: result_hsh.to_json
      end
    end
  end
end
