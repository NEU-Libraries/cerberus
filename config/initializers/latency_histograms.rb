# frozen_string_literal: true

# Times every Atlas round trip, and the pages readers wait on, into shared
# Redis histograms for the admin health page. See docs/outages.md.
#
# Off in the test environment, so the suite neither writes timing data nor
# depends on Redis; spec/services/latency_histogram_spec.rb covers the store
# directly. Each block names its recorder at call time, because the constants
# are reloadable.
unless Rails.env.test?
  Rails.application.config.after_initialize do
    ActiveSupport::Notifications.subscribe(AtlasRb::FaradayHelper::INSTRUMENTATION_EVENT) do |event|
      AtlasLatency.record(event)
    end

    # Fires on the request thread before Current is reset, so the request's
    # RequestTiming is still readable here.
    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |event|
      PageLatency.record(event)
    end
  end
end
