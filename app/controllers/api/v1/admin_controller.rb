module Api
  module V1
    class AdminController < ApplicationController

      before_filter :authenticate_request!
      after_filter :clear_api_user

      def properties
        if current_ability.blank? || current_ability.current_user.blank? || !current_ability.current_user.admin_group?
          render json: { errors: ['Not Authenticated'] }, status: :unauthorized
        end and return

        begin
          item = ActiveFedora::Base.find(params[:id], cast: true)
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        respond_to do |format|
          format.xml { render :xml => item.properties.content }
        end
      end

      def rights
        if current_ability.blank? || current_ability.current_user.blank? || !current_ability.current_user.admin_group?
          render json: { errors: ['Not Authenticated'] }, status: :unauthorized
        end and return

        begin
          item = ActiveFedora::Base.find(params[:id], cast: true)
        rescue NoMethodError
          render json: {error: "An id is required for this action."} and return
        end

        respond_to do |format|
          format.xml { render :xml => item.rightsMetadata.content }
        end
      end
    end
  end
end
