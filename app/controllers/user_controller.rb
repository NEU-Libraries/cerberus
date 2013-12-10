class UsersController < ApplicationController
  include Sufia::UsersControllerBehavior

  def update
    # Only when view_pref parameter is present
    if params[:view_pref].present?
      view_pref  = params[:view_pref]
      
      #make sure it is only one of these strings
      unless view_pref != "grid" || view_pref != "list"
        
        if user_signed_in?
          if @user.view_pref != view_pref
            @user.update_attribute(:only_one_field, view_pref)
            @user.save!
            head :ok
            respond_with(@user)
          end
        end
        
        respond_to do | format |
          format.json
        end

      else
        flash[:error] = "Preference wasn't saved, please try again."
      end
    end
  
  end
end