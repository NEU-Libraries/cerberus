class UsersController < ApplicationController

  # Process changes from profile form
  def update

    @user = current_user

    if params[:view_pref].present?
      view_pref  = params[:view_pref]

      #make sure it is only one of these strings
      if view_pref == 'grid' || view_pref == 'list'

        if @user
          unless @user.view_pref == view_pref
            @user.view_pref = view_pref
            @user.save!
          end
        end

      else
        flash[:error] = "Preference wasn't saved, please try again."
      end
    end

    respond_to do |format|
      format.html
      format.js
    end

  end

end

