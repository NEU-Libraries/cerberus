# frozen_string_literal: true

# Session-built identity: role, groups and NUID. See docs/identity.md.
class User
  include ActiveModel::API
  include ActiveModel::Validations
  extend ActiveModel::Callbacks
  extend Devise::Models

  define_model_callbacks :validation

  attr_accessor :email, :password, :nuid, :name, :groups, :role, :affiliation, :display_name

  devise :custom_authenticatable, authentication_keys: [:email, :password, :nuid, :name, :groups, :role]

  # Builds the identity from an Atlas login payload. The curated Person name is
  # read here, once per sign-in, because the layout renders the name on every
  # page and the test and dev caches are null stores.
  def self.from_atlas(values)
    new(email: values.email, nuid: values.nuid, name: values.name, groups: values.groups,
        role: values.role, affiliation: values.affiliation,
        display_name: curated_name_for(values.nuid))
  end

  # Fail-soft: a failed read signs the user in under their SSO name.
  def self.curated_name_for(nuid)
    return if nuid.blank?

    AtlasRb::User.find_by_nuid(nuid, nuid: nuid)&.dig('display_name').presence
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("User.curated_name_for(#{nuid}): #{e.class} #{e.message}")
    nil
  end

  # A curated name renders verbatim, as NuidResolver's does. Keep the raw-name
  # fallback: Namae parses only person-shaped names, and an organisational one
  # ("Law Library Staffer") parses to nothing. An empty name blanks the navbar
  # user block, taking Log Out with it.
  def pretty_name
    return display_name if display_name.present?

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
