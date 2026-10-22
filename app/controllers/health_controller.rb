# frozen_string_literal: true

# What Nagios polls: one path per capability, answering 200 or 503 with a
# one-word body. ActionController::API, so no session, no sign-in and no
# layout stand between the monitor and the answer, and nothing here names a
# service. See docs/outages.md.
class HealthController < ActionController::API
  before_action { response.headers['Cache-Control'] = 'no-store' }

  def index
    results = HealthCheck.call
    healthy = results.values.all?(&:ok)
    render json:   { status: healthy ? 'ok' : 'degraded', **results.transform_values(&:status) },
           status: healthy ? :ok : :service_unavailable
  end

  def show
    key = HealthCheck.capabilities.find { |capability| capability.to_s == params[:capability] }
    return head :not_found if key.nil?

    result = HealthCheck.check(key)
    render plain: result.status, status: result.ok ? :ok : :service_unavailable
  end
end
