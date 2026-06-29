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
end
