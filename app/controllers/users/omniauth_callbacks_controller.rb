class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def shibboleth
    puts request.env["omniauth.auth"]
    @user = User.find_for_shib(request.env["omniauth.auth"], current_user)

    if @user.persisted?
      sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
      set_flash_message(:notice, :success, :kind => "Shibboleth") if is_navigational_format?
    else
      #Flash message, YOU SHALL NOT PASS
    end
  end
end