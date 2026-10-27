# frozen_string_literal: true

class ErrorsController < ApplicationController
  def forbidden
    render status: :forbidden
  end

  def not_found
    render status: :not_found
  end

  def gone
    render status: :gone
  end

  # An outage can arrive here as well as at /503: ExceptionWrapper maps an
  # exception to its status by exact class name, so a subclass of a mapped
  # error comes in as a 500.
  def internal_server_error
    outage = Outage.for(request.env['action_dispatch.exception'])
    return render_outage(outage) if outage

    render status: :internal_server_error
  end

  # The read-only maintenance window's page. Reached two ways: MaintenanceGate
  # renders the template directly on a refused write, and config.exceptions_app
  # dispatches here by status code. The gate passes `message` as a local; the
  # status-code path has no locals, so the template must not require any.
  #
  # An outage that escaped its controller reaches here too, because
  # config/initializers/outages.rb maps those exceptions to 503. It gets the
  # outage page, not the maintenance one.
  def service_unavailable
    outage = Outage.for(request.env['action_dispatch.exception'])
    return render_outage(outage) if outage

    render status: :service_unavailable
  end
end
