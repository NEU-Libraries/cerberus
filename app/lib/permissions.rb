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
end
