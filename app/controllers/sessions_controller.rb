class SessionsController < Devise::SessionsController
  before_filter :delete_all_app_cookies, :only => :destroy
  after_filter :clear_sign_signout_flash, :only => [:create, :destroy]

  protected

    def clear_sign_signout_flash
      if flash.keys.include?(:notice)
        flash.delete(:notice)
      end
    end

    def delete_all_app_cookies
      # Iterate over all cookies sent by the browser to your app's current path/domain
      cookies.each do |cookie_name, val|
        # Delete each cookie individually, using default options
        cookies.delete(cookie_name.to_sym)

        # If any cookies were set with specific options, you need to add logic here
        # to delete them with those specific options. For example:
        # cookies.delete(cookie_name.to_sym, domain: 'mydomain.com')
      end
    end
end
