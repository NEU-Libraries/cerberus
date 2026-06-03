# frozen_string_literal: true

# Ambient per-request context. Set once at the controller boundary and
# read by every AtlasRb::* call site (controllers, jobs, rake tasks).
#
# Rails 7's ActiveJob ↔ CurrentAttributes integration captures attribute
# values at enqueue and restores them on perform, so jobs and their
# downstream child enqueues see the same nuid (and on_behalf_of) without
# explicit threading.
class Current < ActiveSupport::CurrentAttributes
  # The authenticated acting identity — always the real signed-in user,
  # even while impersonating. Sent as atlas_rb's `User:` header.
  attribute :nuid

  # Acting-as target. Populated only during an acting-as impersonation
  # session; sent as atlas_rb's `On-Behalf-Of:` header so writes are
  # attributed to the target while authorization stays with `nuid`.
  attribute :on_behalf_of

  # View-as target. Read-side only — drives `effective_user` (and thus
  # Ability + SearchBuilder gating). NEVER sent as a write header; view-as
  # is read-only.
  attribute :view_as_nuid
end
