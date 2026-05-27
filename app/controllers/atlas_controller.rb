# frozen_string_literal: true

class AtlasController < ApplicationController
  def login; end

  def process_login
    sign_in_from_atlas(params[:user][:nuid])
  end

  def find_or_create; end

  def process_find_or_create
    attrs = find_or_create_params
    AtlasRb::System::User.find_or_create(**attrs)
    sign_in_from_atlas(attrs[:nuid])
  end

  def user
    @user = current_user
  end

  private

    def find_or_create_params
      {
        nuid:   params[:user][:nuid],
        name:   params[:user][:name].presence,
        email:  params[:user][:email].presence,
        groups: params[:user][:groups].to_s.split("\n").map(&:strip).compact_blank
      }
    end

    def sign_in_from_atlas(nuid)
      user_values = AtlasRb::Authentication.login(nuid)
      user = User.new(
        email:  user_values.email,
        nuid:   user_values.nuid,
        name:   user_values.name,
        groups: user_values.groups,
        role:   user_values.role
      )
      sign_in(user)
      redirect_to atlas_user_path
    end
end
