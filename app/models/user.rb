# frozen_string_literal: true

class User
  include ActiveModel::API
  include ActiveModel::Validations
  extend ActiveModel::Callbacks
  extend Devise::Models

  define_model_callbacks :validation

  attr_accessor :email, :password, :nuid, :name, :groups, :role

  devise :custom_authenticatable, authentication_keys: [:email, :password, :nuid, :name, :groups, :role]

  def pretty_name
    names = Namae.parse(name)[0]
    return "#{names.given} #{names.family}" if names.present?

    ''
  end

  # Atlas-side role mirror. Matches the Atlas Ability layer plan's
  # "admin wildcard short-circuit on both sides" contract — Cerberus's
  # Ability consults this so an Atlas :admin doesn't need every grouper
  # group stuffed onto their record to drive admin-only UI.
  def admin?
    role.to_s == 'admin'
  end

  def to_s
    pretty_name
  end
end
