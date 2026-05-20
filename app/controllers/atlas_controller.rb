# frozen_string_literal: true

class AtlasController < ApplicationController
  def login; end

  def process_login
    user_values = AtlasRb::Authentication.login(params[:user][:nuid])

    user = User.new(
      email:  user_values.email,
      nuid:   user_values.nuid,
      name:   user_values.name,
      groups: user_values.groups
    )

    sign_in(user)
    redirect_to atlas_user_path
  end

  def find_or_create; end

  def process_find_or_create
    nuid = params[:user][:nuid]
    name = params[:user][:name].presence
    email = params[:user][:email].presence
    groups = params[:user][:groups].to_s.split("\n").map(&:strip).compact_blank

    AtlasRb::User.find_or_create(nuid: nuid, groups: groups, name: name, email: email)

    user_values = AtlasRb::Authentication.login(nuid)
    user = User.new(
      email:  user_values.email,
      nuid:   user_values.nuid,
      name:   user_values.name,
      groups: user_values.groups
    )

    sign_in(user)
    redirect_to atlas_user_path
  end

  def user
    @user = current_user
  end
end
