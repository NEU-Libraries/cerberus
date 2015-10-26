class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def shibboleth
    auth = request.env["omniauth.auth"]

    begin
      @user = User.find_for_shib(request.env["omniauth.auth"], current_user)

      if @user.persisted?
        sign_in @user, :event => :authentication #this will throw if @user is not activated
        redirect_to (session[:previous_url] || root_path) and return
      end
    rescue Exception => error
      # We fall down to the error use case
      ExceptionNotifier.notify_exception(error, :env => request.env, :data => {:user => "#{@user.inspect}"})
    end

    flash[:error] = "Error with Shibboleth login - please contact <a href='mailto:Library-Repository-Team@neu.edu'>DRS Staff</a>"
    logger.info "Shibboleth error - #{auth.inspect} #{@user.inspect}"
    redirect_to root_path
  end
end
