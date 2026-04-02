# frozen_string_literal: true

class AtlasController < ApplicationController
  def login; end

  def process_login
    user_values = AtlasRb::Authentication.login(params[:user][:nuid])

    user = User.new(
      email: user_values['email'],
      nuid: user_values['nuid'],
      name: user_values['name'],
      groups: user_values['groups']
    )

    sign_in(user)
    redirect_to atlas_user_path
  end

  def user
    @user = current_user
  end
end
