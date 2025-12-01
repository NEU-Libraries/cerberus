# frozen_string_literal: true

class AtlasController < ApplicationController
  def login; end

  def process_login
    # Use atlas_rb to take nuid value and retrieve user details
    sign_in(User.new(email: "dgcliff@northeastern.edu", nuid: "123123123", name: "Cliff, David", groups: ["group1", "group2"]))
    redirect_to atlas_user_path
  end

  def user
    @user = current_user
  end
end
