# app/custom_auth/devise/models/custom_authenticatable.rb
# Based on https://gist.github.com/madtrick/3916999
module Devise
  module Models
    module CustomAuthenticatable
      extend ActiveSupport::Concern

      module ClassMethods
        # Recreates a resource from session data.
        #
        # It takes as many params as elements in the array returned in
        # serialize_into_session.
        def serialize_from_session(email)
          new(email:)
        end

        # Returns an array with the data from the user that needs to be
        # serialized into the session.
        def serialize_into_session(user)
          [user.email]
        end
      end
    end
  end
end
