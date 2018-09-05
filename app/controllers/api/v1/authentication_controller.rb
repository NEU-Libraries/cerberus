module Api
  module V1
    class AuthenticationController < ApplicationController

      def authenticate_user
        user = User.find_for_database_authentication(email: params[:email])
        if user.valid_password?(params[:password])
          render json: payload(user)
        else
          render json: {errors: ['Invalid Username/Password']}, status: :unauthorized
        end
      end

      private

      def payload(user)
        exp = (Time.now + 1.hour).to_i

        return nil unless user and user.id
        {
          auth_token: JsonWebToken.encode({user_id: user.id, exp: exp}),
          user: {id: user.id, email: user.email}
        }
      end
    end
  end
end
