module Api
  module V1
    class CoreFilesController < ApplicationController

      before_filter :authenticate_request!
      after_filter :clear_api_user

      def show
        begin
          @core_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        if @core_doc.blank? ||
            !(@core_doc.public? || (current_ability.can?(:read, @core_doc))) ||
            @core_doc.in_progress? ||
            @core_doc.incomplete?
          render json: {error: "The item you've requested is unavailable."} and return
        end

        result_hsh = fetch_core_hash

        expires_in 1.hours, :public => true
        render json: result_hsh.to_json
      end

      def file_mods
        begin
          @core_doc = SolrDocument.new ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        if @core_doc.blank? ||
            !(@core_doc.public? || (current_ability.can?(:read, @core_doc))) ||
            @core_doc.in_progress? ||
            @core_doc.incomplete?
          render json: {error: "The item you've requested is unavailable."} and return
        end

        # Safe to proceed

        # params[:id]
        pid = params[:id]
        # Get MODS fedora file path
        config_path = Rails.application.config.fedora_home

        latest_version = ""
        version = 0

        loop do
          datastream_str = "info:fedora/#{pid}/mods/mods.#{version}"
          escaped_datastream = Rack::Utils.escape(datastream_str)
          md5_str = Digest::MD5.hexdigest(datastream_str)
          dir_name = md5_str[0,2]
          file_path = config_path + dir_name + "/" + escaped_datastream

          if File.exist?(file_path)
            latest_version = file_path
            version += 1
          else
            break
          end
        end

        # send file
        send_file latest_version, :filename =>  "neu-#{pid.split(":").last}-MODS.xml", :type => "application/xml", :disposition => 'inline'
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

          result_hsh["content_objects"].reject!{ |k,v| v == "Thumbnail Image" }

          expires_in 1.hours, :public => true
          render json: result_hsh.to_json
        rescue NoMethodError
          render json: {error: "This item has no content objects."} and return
        end
      end

      protected
        def doc_to_url(solr_doc)
          return download_path(solr_doc.pid, :only_path => false) + "?datastream_id=content"
        end

    end
  end
end
