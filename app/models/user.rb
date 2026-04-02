# frozen_string_literal: true

class User
  include ActiveModel::API
  include ActiveModel::Validations
  extend ActiveModel::Callbacks
  extend Devise::Models

  define_model_callbacks :validation

  attr_accessor :email, :password, :nuid, :name, :groups

  devise :custom_authenticatable, authentication_keys: [:email, :password, :nuid, :name, :groups]

  def pretty_name
    names = Namae.parse(name)[0]
    return "#{names.given} #{names.family}" if names.present?

    ''
  end

  def to_s
    pretty_name
  end
end
