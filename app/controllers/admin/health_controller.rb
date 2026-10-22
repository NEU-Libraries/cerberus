# frozen_string_literal: true

module Admin
  # The per-service detail behind the public /health endpoints. It probes
  # afresh rather than reading the cache, because whoever opens it is usually
  # watching a service come back. See docs/outages.md.
  class HealthController < BaseController
    breadcrumb_for 'System health', :admin_health_path

    def show
      @results = HealthCheck.call(fresh: true)
      @jobs = JobQueueStats.call
      @atlas = AtlasLatency.summary
      @atlas_served = AtlasLatency.served(nuid: current_user.nuid)
      @checked_at = Time.current
    end
  end
end
