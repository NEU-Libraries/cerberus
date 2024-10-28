class AdminController < ApplicationController
  include Cerberus::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @page_title = "Admin Home"
    if session[:flash_error]
      flash[:error] = session[:flash_error]
      session[:flash_error] = nil
    end
    if session[:flash_success]
      flash[:notice] = session[:flash_success]
      session[:flash_success] = nil
    end
  end

  private

    def verify_admin
      redirect_to root_path unless current_user.admin?
    end

end
