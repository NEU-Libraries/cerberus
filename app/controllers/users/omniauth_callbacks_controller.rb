class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def shibboleth
    auth = request.env["omniauth.auth"]
    puts auth

    @user = User.find_for_shib(request.env["omniauth.auth"], current_user)

    if @user.persisted?
      flash[:notice] = "Successfully signed in with Shibboleth"
      sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated       
    else
      flash[:error] = "YOU SHALL NOT PASS"
      redirect_to root_path
    end
  end
end