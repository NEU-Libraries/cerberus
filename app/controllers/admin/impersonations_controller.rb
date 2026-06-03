# frozen_string_literal: true

module Admin
  # Start/stop the two impersonation modes (piece 5). Admin-only — the gate
  # is inherited from Admin::BaseController. The session state machine and
  # hydration live in ImpersonationSession (included app-wide via
  # ApplicationController); this controller is just the toggle surface.
  #
  # Acting-as is additionally admin-gated server-side at Atlas (the
  # On-Behalf-Of header is authorized against the admin role), so this gate
  # is the Cerberus half of a two-sided guarantee, not the only one.
  class ImpersonationsController < BaseController
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
        target = params[:nuid].to_s.strip
        user   = target.present? ? hydrate_user(target) : nil
        return redirect_to admin_root_path, alert: 'Enter a valid NUID to impersonate.' if user.nil?

        send(MODES.fetch(mode)[:starter], target)
        redirect_to root_path,
                    notice: "Now #{MODES.fetch(mode)[:verb]} #{user.pretty_name} (#{target}). " \
                            'Use the banner to exit.'
      end
  end
end
