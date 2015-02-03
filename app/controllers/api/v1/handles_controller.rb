module Api
  module V1
    class HandlesController < ApplicationController

      def create_handle
        providedUrl = params[:url]
        if HandleGenerator::handle_exists?(providedUrl)
          handle = HandleGenerator::get_handle(providedUrl)
        else
          handle = HandleGenerator::make_handle(providedUrl)
        end
        render :json => [{:handle => "#{handle}"}]
      end

      def get_handle
        puts "DGCDEBUG"
        providedUrl = params[:url]
        puts providedUrl
        puts "DGCDEBUG2"
        handle = HandleGenerator::get_handle(providedUrl)
        puts handle
        puts "DGCDEBUG3"
        render :json => [{:handle => "#{handle}"}]
      end
    end
  end
end
