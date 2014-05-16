class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def shibboleth
    auth = request.env["omniauth.auth"]

    @user = User.find_for_shib(request.env["omniauth.auth"], current_user)

    begin
      flash[:notice] = "Successfully signed in with Shibboleth"
      sign_in @user, :event => :authentication #this will throw if @user is not activated
      redirect_to root_path
    rescue => error
      flash[:error] = "Error with Shibboleth login"
      logger.error "SHIB ERROR - #{error.class}\n\t#{error.to_s}\n #{error.backtrace.join("\n")}\n\n"
      logger.info "Shibboleth error - #{auth.inspect} #{@user.inspect}"
      redirect_to root_path
    end

  end
end
