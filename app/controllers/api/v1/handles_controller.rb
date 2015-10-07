module Api
  module V1
    class HandlesController < ApplicationController

      include HandleHelper

      def create_handle
        providedUrl = CGI.unescape(params.[:url])
        if handle_exists?(providedUrl)
          handle = retrieve_handle(providedUrl)
        else
          handle = make_handle(providedUrl)
        end
        render :json => [{:handle => "#{handle}"}]
      end

      def get_handle
        providedUrl = CGI.unescape(params.[:url])
        Rails.logger.warn providedUrl
        handle = retrieve_handle(providedUrl)
        render :json => [{:handle => "#{handle}"}]
      end
    end
  end
end
