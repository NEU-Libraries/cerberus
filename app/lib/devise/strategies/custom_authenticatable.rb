# app/custom_auth/devise/strategies/custom_authenticatable.rb
# Based on https://gist.github.com/madtrick/3917079
module Devise
  module Strategies
    # The class needs to inherit from Devise::Strategies::Authenticatable which
    # implements most of the underlying logic for auth strategies in Devise.
    # You can read the code here:
    # https://github.com/heartcombo/devise/blob/main/lib/devise/strategies/authenticatable.rb
    class CustomAuthenticatable < Authenticatable
      # This is the method called by Warden to authenticate a user.
      # More info in https://github.com/wardencommunity/warden/wiki/Strategies#authenticate
      def authenticate!
        if credentials_valid?
          # Signals Warden that the authentication was successful.
          # Expects an instance of the model class that Devise is configured to work with.
          # This should be the user account that matches the provided credentials.
          success!(validated_user)
        else
          # Signals Warden that the authentication failed.
          fail!
        end
      end

      private

      # Returns a boolean indicating whether the provided credentials are valid.
      # This is where you can implement any bespoke logic to do so: Read a file,
      # call a service, validate a one-time-use token, etc.
      #
      # authentication_hash is provided by the base class and includes all the
      # fields included in the login form.
      def credentials_valid?
        # add nuid to devise params
        # take nuid send it to atlas
        # merge atlas values into authentication hash?
        authentication_hash[:email] == "test@email.com" && authentication_hash[:password] == "password"
      end

      def validated_user
        # mapping.to is a reference to the model class that Devise is configured
        # to use that represents user accounts. In this case, it's the User class.
        mapping.to.new(
          email: authentication_hash[:email],
          password: authentication_hash[:password]
        )
      end
    end
  end
end
