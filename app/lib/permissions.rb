# frozen_string_literal: true

module Permissions
  STAFF_EDIT_GROUP = 'northeastern:drs:repository:staff'

  # Gates the My DRS "Programmatic access" section — membership means a user
  # may mint a personal-access JWT to drive the Atlas API directly. Purely a
  # Cerberus-side policy on who sees the feature; Atlas doesn't check this group.
  API_GROUP = 'northeastern:drs:repository:api'

  # The group half of the devolved-admin tier's :privileged-role + group pair
  # (see User#admin_delegate?). Mirrors the matching Atlas-side constant in
  # Atlas's own Permissions concern — both sides gate on the same identifier.
  ADMIN_GROUP = 'northeastern:drs:repository:admin'

  # Depositor stamp for containers nobody personally owns — the institutional
  # hierarchy and the per-community genre showcases. Reachability there is via
  # Grouper, as it was in v1.
  #
  # It matters that this is the anonymous NUID specifically: that principal never
  # authenticates and carries no ability, so recording it as depositor grants
  # nothing to anyone. Letting these fall through to the acting user instead
  # would, under the depositor-implies-edit rule, quietly hand whoever created
  # the container (or ran the seed) edit rights over it.
  UNOWNED_NUID = '000000099'

  # One group grant as the permissions editor renders it
  # (shared/_group_permissions). `ability` is the wire token Atlas expects
  # ('read' / 'edit'), not the human label, so a row round-trips through the
  # form without a label-to-token translation step.
  #
  # `revocable` mirrors Atlas's grant-removal rule: a group grant may only be
  # withdrawn by a member of that group (operators excepted), and Atlas merges a
  # non-member's attempted removal back in rather than refusing the write. A row
  # the acting user cannot revoke is therefore rendered without the controls that
  # would silently attempt it — the same reasoning that hides STAFF_EDIT_GROUP
  # rather than dangling a dead delete control.
  GrantRow = Struct.new(:group_id, :label, :ability, :revocable, keyword_init: true) do
    def revocable?
      !!revocable
    end

    def ability_label
      ability == 'edit' ? 'Manage' : 'View'
    end
  end

  # The portion of `inner`'s audience that is also visible under `outer` —
  # clamping a resource so it can never be more visible than its container.
  # `public` is the universal set on either side: under a public container
  # nothing needs clamping, and a public resource clamps to exactly the
  # container's audience.
  #
  # Mirrors Atlas's TierVisibility.audience_intersect, which does this on the
  # derivative-tier axis. Expressed here too because the cascade is Cerberus
  # workflow: Atlas validates each write against the parent but does not clamp,
  # so the caller decides what the narrowed value should be.
  #
  # Note that disjoint audiences intersect to `[]` — fully private. That is the
  # honest answer (the two audiences share no one), but it means narrowing a
  # container to a group makes a child readable only by some *other* group
  # private rather than re-pointing it, which is worth saying out loud wherever
  # this is surfaced to a person.
  def self.audience_intersect(inner, outer)
    return Array(inner) if Array(outer).include?('public')
    return Array(outer) if Array(inner).include?('public')

    Array(inner) & Array(outer)
  end

  # Whether everyone who can see `inner` can also see `outer` — `public` being
  # the universal audience on either side. Conservative-correct without
  # resolving Grouper membership: two different group names count as different
  # audiences even if their memberships happen to overlap.
  def self.audience_subset?(inner, outer)
    return true  if Array(outer).include?('public')
    return false if Array(inner).include?('public')

    Array(inner).to_set.subset?(Array(outer).to_set)
  end

  # Whether moving from `current` to `submitted` takes audience away.
  #
  # Phrased as "current is no longer contained by what was submitted", which is
  # what makes a same-size swap count as a narrowing too: replacing one group
  # with another removes access for the outgoing group, so descendants that were
  # reachable only through it have to be reconsidered.
  def self.narrowing?(current:, submitted:)
    !audience_subset?(current, submitted)
  end
end
