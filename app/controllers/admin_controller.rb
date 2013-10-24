class AdminController < ApplicationController
  before_filter :authenticate_user!

  def admin_panel
    #
  end

end