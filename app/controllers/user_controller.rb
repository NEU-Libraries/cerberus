class UsersController < ApplicationController
  include Sufia::UsersControllerBehavior

  def update
    if params[:view_pref].present?
      #do stuff
    end
  end
end