class AdminController < ApplicationController
  include Cerberus::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @page_title = "Admin Home"
  end

  private

    def verify_admin
      redirect_to root_path unless current_user.admin?
    end

end
