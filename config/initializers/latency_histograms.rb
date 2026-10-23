# frozen_string_literal: true

# Times the pages readers wait on, and how much of each is waiting on Atlas,
# into shared Redis histograms for the admin health page. See docs/outages.md.
#
# Off in the test environment, so the suite neither writes timing data nor
# depends on Redis; spec/services/latency_histogram_spec.rb covers the store
# directly. Each block names its recorder at call time, because the constants
# are reloadable, and SafeSubscriber keeps a failing recorder from failing the
# request it times.
require Rails.root.join('lib/safe_subscriber').to_s

unless Rails.env.test?
  Rails.application.config.after_initialize do
    SafeSubscriber.subscribe(AtlasRb::FaradayHelper::INSTRUMENTATION_EVENT, label: 'request timing') do |event|
      RequestTiming.record(event)
    end

    # Fires on the request thread before Current is reset, so the request's
    # RequestTiming is still readable here.
    SafeSubscriber.subscribe('process_action.action_controller', label: 'page latency') do |event|
      PageLatency.record(event)
    end
  end
end
