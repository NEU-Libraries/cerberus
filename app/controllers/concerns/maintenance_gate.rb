# frozen_string_literal: true

# Refuses writes while the repository is in a read-only maintenance window.
#
# Keys on the HTTP method rather than an action list, so it is fail-closed by
# construction: a controller added later inherits the refusal without being
# enumerated anywhere. The response RENDERS rather than redirects — Turbo puts a
# non-2xx body in place, and a redirect would lose the frame the librarian
# submitted from. See docs/maintenance.md.
module MaintenanceGate
  extend ActiveSupport::Concern

  # Non-GET requests that write nothing but the Cerberus session row. Every
  # entry must be justified by "this reaches no Atlas write", and the near-miss
  # siblings are deliberately absent: accounts#prefer, atlas#process_find_or_create,
  # and impersonation START (view_as / act_as) all write Atlas. Read
  # docs/maintenance.md before adding one.
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

    # The backstop: anything the method gate lets through still fails, and fails
    # with the same page rather than an unhandled exception.
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
