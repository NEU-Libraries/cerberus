# frozen_string_literal: true

# Session-built identity: role, groups and NUID. See docs/identity.md.
class User
  include ActiveModel::API
  include ActiveModel::Validations
  extend ActiveModel::Callbacks
  extend Devise::Models

  define_model_callbacks :validation

  attr_accessor :email, :password, :nuid, :name, :groups, :role, :affiliation

  devise :custom_authenticatable, authentication_keys: [:email, :password, :nuid, :name, :groups, :role]

  # Keep the raw-name fallback: Namae parses only person-shaped names, and an
  # organisational one ("Law Library Staffer") parses to nothing. An empty name
  # blanks the navbar user block, taking Log Out with it.
  def pretty_name
    names = Namae.parse(name)[0]
    parsed = "#{names&.given} #{names&.family}".strip

    parsed.presence || name.to_s
  end

  def admin?
    role.to_s == 'admin'
  end

  def privileged?
    role.to_s == 'privileged'
  end

  def messageable?
    !role.to_s.in?(%w[guest anonymous])
  end

  def curates_sets?
    messageable?
  end

  def loader_tier?
    role.to_s.in?(%w[loader privileged admin])
  end

  # Role and group jointly — neither alone is sufficient. This predicate covers
  # only the narrower non-admin tier, so a call site must ask
  # `admin? || admin_delegate?` or it locks full admins out of the surface.
  def admin_delegate?
    privileged? && member_of?(Permissions::ADMIN_GROUP)
  end

  # `groups` is nil on the guest fallback, so wrap before `include?`.
  def member_of?(raw_group)
    Array(groups).include?(raw_group)
  end

  # The only carve-out from an active embargo's download withholding. Widening
  # this list hands out embargoed bytes.
  def can_bypass_embargo?
    admin? || member_of?(Permissions::STAFF_EDIT_GROUP)
  end

  def to_s
    pretty_name
  end
end
