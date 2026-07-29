# frozen_string_literal: true

# A cosmetic display name for a Grouper group. Grouper groups are
# colon-separated identifiers (e.g. `northeastern:drs:repository:loaders:marcom`);
# this maps a `raw` identifier to a human-readable `cosmetic` name.
# ApplicationController#pretty_group (and MessagesHelper#pretty_group_name)
# resolve `Group.find_by(raw:)&.cosmetic || raw`, so a row here renames a group
# everywhere it surfaces, and its absence falls back to the raw string. Managed
# via Admin::GroupsController.
class Group < ApplicationRecord
  validates :raw,
            presence:   true,
            uniqueness: true,
            format:     { with: /\A[\w:.-]+\z/, message: 'must be a colon-separated identifier with no spaces' }
  validates :cosmetic, presence: true

  default_scope { order(:raw) }

  # The full known-group registry as [raw, cosmetic] pairs, for the
  # Permissions-tab "add a group" picker's admin/admin_delegate branch (see
  # Transformable#form_preparation) — system-wide arbitrary permission
  # adjustment needs every named group, not just the acting user's own
  # memberships. Ordered by cosmetic (human-readable) name rather than the
  # default raw-identifier order — reads better across ~75 rows in a
  # dropdown than colon-separated identifier order.
  def self.for_select
    reorder(:cosmetic).pluck(:raw, :cosmetic)
  end
end
