module Api
  module V1
    class AdminController < ApplicationController

      before_filter :authenticate_request!
      after_filter :clear_api_user

      def properties
        if current_ability.blank? || current_ability.current_user.blank?
          if !current_ability.current_user.admin_group?
            render json: { errors: ['Not Authenticated'] }, status: :unauthorized
          end
        end and return

        begin
          item = ActiveFedora::Base.find(params[:id], cast: true)
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        render json: {properties: item.properties.content} and return
      end

      def rights
        if current_ability.blank? || current_ability.current_user.blank?
          if !current_ability.current_user.admin_group?
            render json: { errors: ['Not Authenticated'] }, status: :unauthorized
          end
        end and return

        begin
          item = ActiveFedora::Base.find(params[:id], cast: true)
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        render json: {rights: item.rightsMetadata.content} and return
      end
    end
  end
end
