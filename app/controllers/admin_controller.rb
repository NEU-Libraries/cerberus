class AdminController < ApplicationController
  include Cerberus::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @page_title = "Admin Home"
  end

  private

    def verify_admin
      if current_user.nil?
        flash[:error] = "You do not have privileges to use that feature"
        render_403
      elsif !(current_user.admin? || current_user.admin_group?)
        flash[:error] = "You do not have privileges to use that feature"
        render_403
      end
    end

end
