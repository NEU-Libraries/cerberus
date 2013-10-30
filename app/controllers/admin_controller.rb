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
      redirect_to root_path unless current_user.role.eql? "admin"
    end

end