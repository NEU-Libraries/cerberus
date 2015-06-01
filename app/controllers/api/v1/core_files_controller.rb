module Api
  module V1
    class CoreFilesController < ApplicationController
      include ModsDisplay::ControllerExtension

      def show
        @core_file = ActiveFedora::Base.find(params[:id], cast: true)
        @mods = render_mods_display(@core_file).to_json.html_safe
        render json: @mods
      end
    end
  end
end
