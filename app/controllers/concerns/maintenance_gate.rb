# frozen_string_literal: true

# Refuses writes while the repository is in a read-only maintenance window.
#
# Atlas is the boundary — it refuses the write whatever Cerberus does, and
# atlas_rb raises AtlasRb::ReadOnlyModeError when it does. This gate exists so a
# librarian meets a page that explains the window instead of an exception, and
# so a write never travels to Atlas just to be turned back.
#
# It keys on the HTTP method rather than an action list, which makes it
# fail-closed by construction: a controller added later inherits the refusal
# without being enumerated anywhere. The usual objection to method filtering —
# that a GET can write — does not apply, because this is not the boundary.
#
# The response renders rather than redirects. Turbo renders a non-2xx body in
# place, so the notice lands in the frame the librarian submitted from; a
# redirect would need a 303 and would lose that context.
module MaintenanceGate
  extend ActiveSupport::Concern

  # Non-GET requests that write nothing but the Cerberus session row, and so
  # stay open while the repository is closed. Cerberus's own database keeps
  # taking writes throughout — the session store is what sign-in needs, and an
  # app-wide read-only database would lock out the operator running the window.
  #
  # Each entry has to be justified by "this reaches no Atlas write":
  #   devise/sessions           — sign-in reads Atlas (GET /user) and writes a
  #                               session row; sign-out only clears one.
  #   accounts#switch           — records which of a person's accounts is acting.
  #                               Note that accounts#prefer is NOT here: it
  #                               writes Atlas's preferred_account.
  #   download_queue            — the queue lives in the session, and downloads
  #                               keep working, so assembling one should too.
  #   admin/impersonations#destroy — EXITING only. The session is torn down
  #                               before the end event is emitted, so an admin
  #                               must always be able to leave a session they
  #                               have already left. The end event itself is
  #                               lost during a window: an impersonation exited
  #                               inside one leaves no end row in the ledger.
  #                               Starting a session is NOT here — neither
  #                               view_as nor act_as. Both record a
  #                               session-start AuditEvent in Atlas first, and
  #                               fail closed if it does not land, so neither
  #                               can work during a window whatever this gate
  #                               does. Refusing them here makes the message
  #                               clear and saves a round trip.
  #   catalog#index             — Blacklight routes search at GET *and* POST.
  #                               A long query arrives as a POST, so without
  #                               this a window would refuse searching.
  #   catalog#track             — records the result counter in the session so
  #                               next/previous works from a record page.
  #   atlas#process_login       — the NUID sign-in shim (absent in production).
  #                               Reads Atlas the same way devise does. Note
  #                               that atlas#process_find_or_create is NOT
  #                               here: it provisions a user in Atlas.
  #
  # The maintenance surface itself is not listed. It opts out in its own
  # controller, next to the code the exemption protects.
  SESSION_ONLY_WRITES = %w[
    devise/sessions#create
    devise/sessions#destroy
    accounts#switch
    download_queue#create
    download_queue#destroy
    download_queue#destroy_all
    admin/impersonations#destroy
    catalog#index
    catalog#track
    atlas#process_login
  ].freeze

  included do
    before_action :block_writes_in_maintenance!, unless: :maintenance_exempt_request?

    # The backstop. Anything the method gate lets through — a GET-shaped write,
    # an allowlisted action that turns out to reach Atlas — still fails, and
    # fails with the same page rather than an unhandled exception.
    rescue_from AtlasRb::ReadOnlyModeError, with: :render_maintenance_notice
  end

  private

    def block_writes_in_maintenance!
      return unless MaintenanceMode.read_only?

      render_maintenance_notice
    end

    def maintenance_exempt_request?
      request.get? || request.head? ||
        SESSION_ONLY_WRITES.include?("#{controller_path}##{action_name}")
    end

    def render_maintenance_notice(_exception = nil)
      response.headers['Retry-After'] = MaintenanceMode.retry_after.to_s if MaintenanceMode.retry_after
      render template: 'errors/service_unavailable',
             status:   :service_unavailable,
             layout:   'application',
             locals:   { message: MaintenanceMode.message }
    end
end
