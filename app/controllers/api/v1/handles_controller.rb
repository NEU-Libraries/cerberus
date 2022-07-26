module Api
  module V1
    class HandlesController < ApplicationController

      include HandleHelper

      def create_handle
        providedUrl = CGI.unescape(params[:url])
        if handle_exists?(providedUrl)
          handle = retrieve_handle(providedUrl)
          render :json => {:handle => "#{handle}", :new => false}
        else
          handle = make_handle(providedUrl)
          render :json => {:handle => "#{handle}", :new => true}
        end
      end

      def get_handle
        providedUrl = CGI.unescape(params[:url])
        handle = retrieve_handle(providedUrl)
        render :json => {:handle => "#{handle}"}
      end

      def change_handle
        if params[:password] == ENV["HANDLE_UPDATE_PASSWORD"]
          handle = update_handle(params[:handle], CGI.unescape(params[:url]))
          if handle.nil?
            render_500(StandardError.new) and return
          end
          render :json => {:handle => "#{handle}"}
        else
          render_403 and return
        end
      end
    end
  end
end
