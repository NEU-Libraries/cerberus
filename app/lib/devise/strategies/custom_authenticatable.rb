# frozen_string_literal: true

# Warden strategy backing `devise :custom_authenticatable`. See docs/identity.md.
module Devise
  module Strategies
    class CustomAuthenticatable < Authenticatable
      def authenticate!
        if credentials_valid?
          success!(validated_user)
        else
          fail!
        end
      end

      private

        # Verifies nothing — every attempt passes, so whatever the
        # authentication hash carries becomes the signed-in identity. The NUID
        # lookup against Atlas that would validate it is not wired here; the
        # app signs in through AtlasController#sign_in_from_atlas instead.
        def credentials_valid?
          true
        end

        def validated_user
          mapping.to.new(
            nuid:     authentication_hash[:nuid],
            email:    authentication_hash[:email],
            password: authentication_hash[:password]
          )
        end
    end
  end
end
