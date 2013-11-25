class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def shibboleth
    shibInfo = request.env["omniauth.auth"]
    puts "SHIB INFO"
    puts shibInfo
  end
end