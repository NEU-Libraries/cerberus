# frozen_string_literal: true

class User < ApplicationRecord
  include ActiveModel::API
  include ActiveModel::Validations
  extend ActiveModel::Callbacks
  extend Devise::Models

  define_model_callbacks :validation

  attr_accessor :email, :password

  devise :custom_authenticatable, authentication_keys: [:email, :password]
end
