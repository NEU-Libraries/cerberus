# frozen_string_literal: true

# Times every Atlas round trip into a shared Redis histogram for the admin
# health page. See docs/outages.md.
#
# Off in the test environment, so the suite neither writes timing data nor
# depends on Redis; spec/services/latency_histogram_spec.rb covers the store
# directly. The block names AtlasLatency at call time, because the constant is
# reloadable.
unless Rails.env.test?
  Rails.application.config.after_initialize do
    ActiveSupport::Notifications.subscribe(AtlasRb::FaradayHelper::INSTRUMENTATION_EVENT) do |event|
      AtlasLatency.record(event)
    end
  end
end
