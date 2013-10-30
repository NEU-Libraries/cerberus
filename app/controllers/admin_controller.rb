class AdminController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects
  
  before_filter :authenticate_user!
  before_filter :deny_to_visitors

  def admin_panel
    #
  end

  def modify_employee
    #
  end

end