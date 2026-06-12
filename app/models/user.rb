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

  # Role gate for the deposit form's proxy radio (piece 3 of the v2
  # auth + provenance plan). Group membership still selects *which*
  # collections the user can deposit into; this only governs whether
  # the radio surface is rendered.
  def privileged?
    role.to_s == 'privileged'
  end

  # Inbox eligibility: guests and the anonymous tier are excluded from
  # messaging entirely — the guest NUID is a shared fallback identity with
  # no inbox of its own.
  def messageable?
    !role.to_s.in?(%w[guest anonymous])
  end

  # Sets (personal curation) share the inbox's human-role floor: guests and
  # the anonymous tier cannot own Sets. One concept, two surfaces — if the
  # floor ever diverges, split the predicates then.
  def curates_sets?
    messageable?
  end

  # The loader surface's coarse role gate (shared by LoadsController and
  # the My Loaders page/menu). Which Loaders show inside is the per-loader
  # Grouper group's concern — see Loader.available_to.
  def loader_tier?
    role.to_s.in?(%w[loader privileged admin])
  end

  def to_s
    pretty_name
  end
end
