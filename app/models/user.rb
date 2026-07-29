# frozen_string_literal: true

class User
  include ActiveModel::API
  include ActiveModel::Validations
  extend ActiveModel::Callbacks
  extend Devise::Models

  define_model_callbacks :validation

  attr_accessor :email, :password, :nuid, :name, :groups, :role, :affiliation

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

  # Role gate for the deposit form's proxy ("upload as") radio. Group membership
  # still selects *which* collections the user can deposit into; this only
  # governs whether the radio surface is rendered.
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

  # The devolved-admin tier: :privileged role + the admin group, jointly —
  # neither alone is sufficient (mirrors the Atlas-side Ability's identical
  # pairing). Grants a named subset of Admin::BaseController surfaces below
  # the full :admin role's blanket access; call sites combine this with
  # admin? (`admin? || admin_delegate?`) since :admin always short-circuits
  # and this predicate only covers the narrower non-admin case.
  def admin_delegate?
    privileged? && member_of?(Permissions::ADMIN_GROUP)
  end

  # Grouper group membership test. `groups` is the IdP-asserted array carried
  # on the session-built User (nil for the guest fallback), so wrap in Array
  # before `include?` — the app-wide idiom, named here so group gates read as
  # `member_of?(...)` instead of re-typing `Array(...).include?(...)`.
  def member_of?(raw_group)
    Array(groups).include?(raw_group)
  end

  # The only carve-out from an active embargo's download withholding: DRS
  # staff (grouper) or an Atlas Admin. Distinct from STAFF_EDIT_GROUP's usual
  # role (an always-on edit group) — here it's read-side, standing in for
  # "someone who can confirm this restriction is intentional."
  def can_bypass_embargo?
    admin? || member_of?(Permissions::STAFF_EDIT_GROUP)
  end

  def to_s
    pretty_name
  end
end
