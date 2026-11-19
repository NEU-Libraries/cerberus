# frozen_string_literal: true

# Ambient per-request context. Set once at the controller boundary and
# read by every AtlasRb::* call site (controllers, jobs, rake tasks).
#
# Rails does not carry these across enqueue and perform. ApplicationJob
# serializes nuid by hand and restores it on perform, and sets request_id to
# the job's own id; the other attributes are nil inside a job.
class Current < ActiveSupport::CurrentAttributes
  # The authenticated acting identity — always the real signed-in user,
  # even while impersonating. Signed as atlas_rb's `sub` claim.
  attribute :nuid

  # The account the person has switched to — their email (the account key: a NUID
  # can hold several staff/student logins, each with its own groups). Set only
  # after an explicit switch; signed as atlas_rb's `acct` claim so calls act as
  # that account. nil (the default, for everyone who hasn't switched) sends no
  # claim, and Atlas resolves the person's preferred account.
  attribute :account_email

  # Acting-as target. Populated only during an acting-as impersonation
  # session; signed as atlas_rb's `obo` claim so writes are
  # attributed to the target while authorization stays with `nuid`.
  attribute :on_behalf_of

  # View-as target, recorded for the request. Nothing gates on it:
  # `effective_user` reads the session, and gated reads pass `viewer_nuid`
  # explicitly. NEVER sent as a write header; view-as is read-only.
  attribute :view_as_nuid

  # The request's RequestTiming. Set before any callback, so that the worker
  # threads ParallelAtlasReads spawns copy the same object by reference and their
  # Atlas calls count toward this request. Never sent to Atlas.
  attribute :request_timing

  # The id this request or job logs under, sent to Atlas as X-Request-Id so
  # Atlas's log lines carry it. A log label only; Atlas trusts nothing about it.
  attribute :request_id
end
