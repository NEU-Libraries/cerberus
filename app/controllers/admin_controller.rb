class AdminController < ApplicationController
  before_filter :authenticate_user!
  before_filter :deny_to_visitors

  def admin_panel
    #
  end

  def modify_employee
    #
  end

  protected

    def deny_to_visitors
      if !current_user.admin
        flash[:notice] = "Admin path denied, your role is #{current_user.role}"
        redirect_to root_path
      end
    end

end