# frozen_string_literal: true

module Admin
  # Toggle surface for the two impersonation modes; the state machine lives in
  # ImpersonationSession. See docs/identity.md.
  #
  # Two gates, not one. create_acting_as keeps the inherited strict
  # require_admin — act-as stays :admin-only even for a delegate who cleared the
  # broader gate to reach this controller. Everything else is open to :admin or
  # the devolved-admin tier (User#admin_delegate?).
  class ImpersonationsController < BaseController
    skip_before_action :require_admin, except: [:create_acting_as]
    before_action :require_admin_or_delegate, except: [:create_acting_as]

    breadcrumb_for 'Impersonation', :admin_impersonation_path

    include UserDirectorySearchable

    # Exempt because this controller manages the impersonation session itself:
    # without the skip, the banner's Exit (DELETE) and a mode switch (POST)
    # would trip the guard and end the session with a misleading message.
    skip_before_action :reject_writes_in_view_as

    MODES = {
      acting_as: { starter: :start_acting_as, verb: 'acting as' },
      view_as:   { starter: :start_view_as,   verb: 'viewing as' }
    }.freeze

    def new; end

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
        # Safe to swallow: start_* emits the audit event before establishing the
        # session, so a failed emit means no session was set.
        Rails.logger.error("impersonation start audit emit failed: #{e.class} #{e.message}")
        redirect_to admin_root_path,
                    alert: 'Could not start the session — the audit service is unavailable. Please try again.'
      end

      def resolve_target
        nuid = params[:nuid].to_s.strip
        return if nuid.blank?

        hydrate_user(nuid)
      end
  end
end
