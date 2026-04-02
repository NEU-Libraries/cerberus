# frozen_string_literal: true

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
        def serialize_from_session(email, nuid, name, groups)
          # new(email:)
          resource = new
          resource.email = email
          resource.nuid = nuid
          resource.name = name
          resource.groups = groups
          resource
        end

        # Returns an array with the data from the user that needs to be
        # serialized into the session.
        def serialize_into_session(user)
          [user.email, user.nuid, user.name, user.groups]
        end
      end
    end
  end
end
