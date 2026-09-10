# frozen_string_literal: true

module Permissions
  STAFF_EDIT_GROUP = 'northeastern:drs:repository:staff'

  # Cerberus-side policy only: Atlas does not check this group.
  API_GROUP = 'northeastern:drs:repository:api'

  # Mirrors Atlas's own constant -- both sides gate on this identifier.
  ADMIN_GROUP = 'northeastern:drs:repository:admin'

  # Depositor stamp for containers nobody personally owns. The ANONYMOUS nuid
  # specifically: it never authenticates, so depositor-implies-edit grants
  # nothing. Falling back to the acting user would hand them edit rights.
  UNOWNED_NUID = '000000099'

  # `ability` is the wire token Atlas expects, not the human label.
  # See docs/permissions.md for the revocable rule.
  GrantRow = Struct.new(:group_id, :label, :ability, :revocable, keyword_init: true) do
    def revocable?
      !!revocable
    end

    def ability_label
      ability == 'edit' ? 'Manage' : 'View'
    end
  end

  # Clamps a resource so it can never out-visible its container. Atlas
  # validates against the parent but does NOT clamp -- see docs/permissions.md.
  def self.audience_intersect(inner, outer)
    return Array(inner) if Array(outer).include?('public')
    return Array(outer) if Array(inner).include?('public')

    Array(inner) & Array(outer)
  end

  # The WHOLE envelope, never `read` alone: Atlas assigns edit_groups,
  # edit_users and embargo unconditionally from the payload, so a partial
  # hash silently blanks them. depositor/proxy_uploader are write-once and
  # are omitted on purpose. See docs/permissions.md.
  def self.envelope_with_read(current, read)
    { 'embargo'    => current.embargo,
      'read'       => Array(read),
      'edit'       => Array(current.edit),
      'edit_users' => Array(current.edit_users) }
  end

  # Two group names are different audiences even if their memberships overlap.
  def self.audience_subset?(inner, outer)
    return true  if Array(outer).include?('public')
    return false if Array(inner).include?('public')

    Array(inner).to_set.subset?(Array(outer).to_set)
  end

  # A same-size swap counts: the outgoing group loses access. See docs/permissions.md.
  def self.narrowing?(current:, submitted:)
    !audience_subset?(current, submitted)
  end
end
