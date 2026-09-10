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

  def internal_server_error
    render status: :internal_server_error
  end

  # The read-only maintenance window's page. Reached two ways: MaintenanceGate
  # renders the template directly on a refused write, and config.exceptions_app
  # dispatches here by status code. The gate passes `message` as a local; the
  # status-code path has no locals, so the template must not require any.
  def service_unavailable
    render status: :service_unavailable
  end
end
