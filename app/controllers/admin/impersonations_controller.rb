# frozen_string_literal: true

module Admin
  # Start/stop the two impersonation modes. The session state machine and
  # hydration live in ImpersonationSession (included app-wide via
  # ApplicationController); this controller is just the toggle surface.
  #
  # Two different gates, not one: every action except create_acting_as is
  # reachable by :admin or the devolved-admin tier (User#admin_delegate?) —
  # view-as, recipients typeahead, destroy. create_acting_as (act-as) keeps
  # the inherited strict require_admin — act-as stays :admin-only even for a
  # delegate who cleared the broader gate to get here, matching the view
  # (_start.html.haml), which only renders the "Act as" control for a full
  # admin. Acting-as is additionally admin-gated server-side at Atlas (the
  # On-Behalf-Of header is authorized against the admin role) — defense in
  # depth, not the only backstop. Atlas's own devolved-admin grant
  # (apply_admin_delegate_abilities) opens `:create AuditEvent` for the
  # session-start emit that view-as also needs, but does not touch
  # On-Behalf-Of / acting-as at all.
  class ImpersonationsController < BaseController
    skip_before_action :require_admin, except: [:create_acting_as]
    before_action :require_admin_or_delegate, except: [:create_acting_as]

    breadcrumb_for 'Impersonation', :admin_impersonation_path

    include UserDirectorySearchable

    # This controller manages the impersonation session itself, so it is
    # exempt from the view-as write guard — otherwise the banner's Exit
    # (a DELETE) and switching modes (a POST) would trip the guard and end
    # the session with a misleading "write attempted" message instead of
    # doing their job. enforce_impersonation_ttl / set_impersonation_context
    # still run.
    skip_before_action :reject_writes_in_view_as

    MODES = {
      acting_as: { starter: :start_acting_as, verb: 'acting as' },
      view_as:   { starter: :start_view_as,   verb: 'viewing as' }
    }.freeze

    # The hub action surface: renders the NUID-entry start form. Reached from
    # the admin dashboard's Impersonation card, matching the other admin
    # actions (Re-parent, Linked members) which open onto their own page.
    def new; end

    # Typeahead JSON for the Target-user picker (see UserDirectorySearchable).
    # The directory's role exclusions are apt here too — impersonation targets
    # real human users, never self/system/anonymous.
    def recipients
      render json: user_directory_results
    end

    def create_acting_as
      begin_impersonation(:acting_as)
    end

    def create_view_as
      begin_impersonation(:view_as)
    end

    def destroy
      end_impersonation
      redirect_to admin_root_path, notice: 'Impersonation ended.'
    end

    private

      def begin_impersonation(mode)
        user = resolve_target
        return redirect_to admin_root_path, alert: 'Enter a valid NUID to impersonate.' if user.nil?

        cfg = MODES.fetch(mode)
        send(cfg[:starter], user.nuid)
        redirect_to root_path,
                    notice: "Now #{cfg[:verb]} #{user.pretty_name} (#{user.nuid}). Use the banner to exit."
      rescue Faraday::Error => e
        # Fail-closed: start_* records the session-start AuditEvent before
        # establishing the session, so a failed emit means no session was
        # set. Don't strand the admin in a 500 — surface it and let them retry.
        Rails.logger.error("impersonation start audit emit failed: #{e.class} #{e.message}")
        redirect_to admin_root_path,
                    alert: 'Could not start the session — the audit service is unavailable. Please try again.'
      end

      # Hydrate the target NUID into a User (name for the flash, nuid for the
      # session). nil for a blank entry (no Atlas call) or a failed lookup.
      def resolve_target
        nuid = params[:nuid].to_s.strip
        return if nuid.blank?

        hydrate_user(nuid)
      end
  end
end
