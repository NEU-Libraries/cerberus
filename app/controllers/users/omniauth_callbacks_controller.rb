class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def shibboleth
    auth = request.env["omniauth.auth"]
    puts auth

    @user = User.find_for_shib(request.env["omniauth.auth"], current_user)

    if @user.persisted?

      if auth.info.employee == "staff"
        @user.role = 'employee'
        @user.save!
        Sufia.queue.push(EmployeeCreateJob.new(auth.info.nuid))       
      end

      sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
      set_flash_message(:notice, :success, :kind => "Shibboleth") if is_navigational_format?
    else
      #Flash message, YOU SHALL NOT PASS
    end
  end
end