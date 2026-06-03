# frozen_string_literal: true

# Acting-as / view-as impersonation (piece 5 of the v2 auth + provenance
# work). Included into ApplicationController so it governs every request —
# an impersonating admin browses the whole app, not just an admin surface.
#
# Two mutually-exclusive modes, both admin-only:
#
#   acting-as  WRITE impersonation. The admin stays the authenticated
#              identity (Current.nuid) but Current.on_behalf_of is set to
#              the target, so atlas_rb writes carry `On-Behalf-Of: <target>`
#              (auto-threaded via the default_on_behalf_of callable). Atlas
#              authorizes the admin and stamps the target as provenance.
#
#   view-as    READ-only impersonation. Sets view_as_nuid, which drives
#              {#effective_user} — the single user that BOTH Ability and
#              SearchBuilder consult. Writes are rejected
#              (#reject_writes_in_view_as); the authenticated identity is
#              untouched.
#
# Session state lives in the Rails session cookie with a 30-minute sliding
# (inactivity) TTL. All termination paths funnel through #end_impersonation.
module ImpersonationSession
  extend ActiveSupport::Concern

  IMPERSONATION_TTL = 30.minutes

  included do
    before_action :enforce_impersonation_ttl
    before_action :set_impersonation_context
    before_action :reject_writes_in_view_as
    helper_method :acting_as?, :view_as?, :impersonating?,
                  :acting_as_nuid, :view_as_nuid,
                  :impersonation_target, :effective_user
  end

  def acting_as?
    session[:acting_as_nuid].present?
  end

  def view_as?
    session[:view_as_nuid].present?
  end

  def impersonating?
    acting_as? || view_as?
  end

  def acting_as_nuid
    session[:acting_as_nuid]
  end

  def view_as_nuid
    session[:view_as_nuid]
  end

  # The user whose READ view is rendered. Only view-as diverges from the
  # authenticated admin. Memoized per request. Fails CLOSED: if the view-as
  # target can't be hydrated from Atlas, fall back to a least-privilege
  # guest-shaped user — never leak the admin's view under a view-as banner.
  def effective_user
    @effective_user ||= view_as? ? view_as_target : current_user
  end

  # The hydrated target user (acting-as or view-as), for the banner's
  # name/NUID display. nil if no session or hydration fails.
  def impersonation_target
    return @impersonation_target if defined?(@impersonation_target)

    @impersonation_target = hydrate_user(acting_as_nuid || view_as_nuid)
  end

  def start_acting_as(target_nuid)
    end_impersonation # mutual exclusion + clean clock
    session[:acting_as_nuid] = target_nuid
    stamp_impersonation_clock
    # AUDIT (deferred): emit impersonation_started{mode: acting_as}.
    # See ~/projects/gap_reports/impersonation_session_audit_gap.md.
  end

  def start_view_as(target_nuid)
    end_impersonation
    session[:view_as_nuid] = target_nuid
    stamp_impersonation_clock
    # AUDIT (deferred): emit impersonation_started{mode: view_as}.
  end

  def end_impersonation
    # AUDIT (deferred): emit impersonation_ended for the active mode.
    session.delete(:acting_as_nuid)
    session.delete(:view_as_nuid)
    session.delete(:impersonation_started_at)
    session.delete(:impersonation_last_active_at)
  end

  private

    # Push the impersonation state into the ambient Current context after
    # ApplicationController#set_current_nuid has set the admin identity.
    # on_behalf_of drives write attribution; view_as_nuid is read-only
    # bookkeeping (effective_user is the real consumer).
    def set_impersonation_context
      Current.on_behalf_of = acting_as_nuid
      Current.view_as_nuid = view_as_nuid
    end

    # View-as is read-only. A state-changing request ends the session loudly
    # rather than silently performing (or silently dropping) a write.
    def reject_writes_in_view_as
      return unless view_as?
      return if request.get? || request.head?

      end_impersonation
      redirect_to main_app.root_path,
                  alert: 'Write attempted during View-as — the session has ended.'
    end

    # Sliding 30-minute inactivity window. Each request either expires the
    # session (last activity older than the TTL) or refreshes the clock.
    def enforce_impersonation_ttl
      return unless impersonating?

      last = session[:impersonation_last_active_at]
      if last.present? && Time.iso8601(last) <= IMPERSONATION_TTL.ago
        end_impersonation
      else
        session[:impersonation_last_active_at] = Time.current.iso8601
      end
    end

    def stamp_impersonation_clock
      now = Time.current.iso8601
      session[:impersonation_started_at]     = now
      session[:impersonation_last_active_at] = now
    end

    # No DB — User is a session-built ActiveModel. Hydrate role+groups from
    # Atlas with the same GET /user call SSO sign-in uses.
    def hydrate_user(nuid)
      return if nuid.blank?

      values = AtlasRb::Authentication.login(nuid)
      User.new(
        email:  values.email,
        nuid:   values.nuid,
        name:   values.name,
        groups: values.groups,
        role:   values.role
      )
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("Impersonation hydrate failed for #{nuid}: #{e.class} #{e.message}")
      nil
    end

    # Fail-closed view-as target: a hydration miss yields a public-only
    # guest, not the admin.
    def view_as_target
      @view_as_target ||= hydrate_user(view_as_nuid) || User.new(groups: [], role: 'guest')
    end
end
