# frozen_string_literal: true

# Acting-as (write) and view-as (read-only) impersonation, included into
# ApplicationController so it governs every request. See docs/identity.md.
#
# rubocop:disable Metrics/ModuleLength -- a cohesive state machine (predicates,
# lifecycle, TTL, context plumbing, hydration); splitting it would scatter the
# session logic across files for no readability gain.
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

  # The user whose READ view is rendered, and the single user both Ability and
  # SearchBuilder must consult — never current_user directly. Fails closed: a
  # view-as target that will not hydrate falls back to a guest-shaped user
  # rather than leaking the admin's own view under a view-as banner.
  def effective_user
    @effective_user ||= view_as? ? view_as_target : current_user
  end

  def impersonation_target
    return @impersonation_target if defined?(@impersonation_target)

    @impersonation_target = hydrate_user(acting_as_nuid || view_as_nuid)
  end

  def start_acting_as(target_nuid)
    end_impersonation # mutual exclusion + clean clock
    # Emit before establishing the session, so an admin can never impersonate
    # without an audit trail. A failed emit raises and no session is set.
    emit_impersonation_event('impersonation_started', target_nuid, 'acting_as')
    session[:acting_as_nuid] = target_nuid
    stamp_impersonation_clock
  end

  def start_view_as(target_nuid)
    end_impersonation
    emit_impersonation_event('impersonation_started', target_nuid, 'view_as')
    session[:view_as_nuid] = target_nuid
    stamp_impersonation_clock
  end

  def end_impersonation
    mode   = ('acting_as' if acting_as?) || ('view_as' if view_as?)
    target = acting_as_nuid || view_as_nuid

    session.delete(:acting_as_nuid)
    session.delete(:view_as_nuid)
    session.delete(:impersonation_started_at)
    session.delete(:impersonation_last_active_at)

    # Best-effort from here: the session is already torn down, so a failed emit
    # must never trap the admin mid-impersonation.
    return unless mode

    begin
      emit_impersonation_event('impersonation_ended', target, mode)
    rescue Faraday::Error, AtlasRb::Error => e
      # AtlasRb::Error must stay in this rescue: a read-only maintenance window
      # raises AtlasRb::ReadOnlyModeError, and letting it escape would land the
      # admin on the maintenance page and claim an exit failed that succeeded.
      Rails.logger.error("impersonation_ended audit emit failed: #{e.class} #{e.message}")
    end
  end

  private

    # Runs after ApplicationController#set_current_nuid has set the admin
    # identity. on_behalf_of drives write attribution; view_as_nuid is read-only
    # bookkeeping and must never become a write header.
    def set_impersonation_context
      Current.on_behalf_of = acting_as_nuid
      Current.view_as_nuid = view_as_nuid
    end

    # View-as is read-only: a state-changing request ends the session loudly.
    # A redirect is discarded when the write came from inside a turbo-frame, so
    # the reply has to be a turbo-stream refresh instead.
    def reject_writes_in_view_as
      return unless view_as?
      return if request.get? || request.head?

      end_impersonation
      alert = 'Write attempted during View-as — the session has ended.'
      return redirect_to(root_path, alert: alert) unless turbo_frame_request?

      flash[:alert] = alert
      # request_id: nil is load-bearing. It defaults to the current request's id,
      # and Turbo drops a refresh whose id it has already seen — which is true of
      # every refresh issued in reply to the request that triggered it.
      render turbo_stream: turbo_stream.refresh(request_id: nil)
    end

    def enforce_impersonation_ttl
      return unless impersonating?

      last = session[:impersonation_last_active_at]
      if last.present? && Time.iso8601(last) <= IMPERSONATION_TTL.ago
        end_impersonation
      else
        session[:impersonation_last_active_at] = Time.current.iso8601
      end
    end

    # actor_nuid is the admin, passed explicitly: the gem sends it as the `User:`
    # header and records it as the principal, so the admin gate still holds on an
    # impersonation_ended emit fired after the session is gone.
    def emit_impersonation_event(action, target_nuid, mode)
      AtlasRb::AuditEvent.emit(
        action:            action,
        actor_nuid:        current_user&.nuid,
        on_behalf_of_nuid: target_nuid,
        mode:              mode
      )
    end

    def stamp_impersonation_clock
      now = Time.current.iso8601
      session[:impersonation_started_at]     = now
      session[:impersonation_last_active_at] = now
    end

    # A plain profile lookup, NOT an on-behalf-of operation: it must not inherit
    # the ambient Current.on_behalf_of of an acting-as session. The call sets
    # `User:` to the target (a non-admin), so a leaked On-Behalf-Of makes Atlas
    # refuse the self-lookup and the banner reads "Unknown user".
    def hydrate_user(nuid)
      return if nuid.blank?

      values = Current.set(on_behalf_of: nil) { AtlasRb::Authentication.login(nuid) }
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

    # Fail-closed: a hydration miss yields a public-only guest, not the admin.
    def view_as_target
      @view_as_target ||= hydrate_user(view_as_nuid) || User.new(groups: [], role: 'guest')
    end
end
# rubocop:enable Metrics/ModuleLength
