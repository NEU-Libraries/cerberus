# frozen_string_literal: true

# Atlas round-trip times for the admin health page, fed by atlas_rb's
# request.atlas_rb event. See docs/outages.md.
module AtlasLatency
  # The health probes call this every few seconds whoever is watching, so
  # counting them would report the monitor's traffic as the app's. The admin
  # page's own read of Atlas's figures is left out for the same reason.
  IGNORED_PATHS = %w[/health /up /metrics/latency].freeze

  module_function

  def histogram = LatencyHistogram.new('atlas')

  def record(event)
    env = event.payload
    return if IGNORED_PATHS.include?(env.url&.path)

    error = event.payload[:exception_object]
    histogram.record(event.duration,
                     failed:  error.present? || env.status.to_i >= 500,
                     timeout: error.is_a?(Faraday::TimeoutError))
  end

  def summary = histogram.summary

  # Atlas's own figures, timed from the top of its Rack stack, so they leave out
  # only what happens outside Atlas's Rails app. nil when Atlas cannot give
  # them, which includes a Redis outage on its side.
  def served(nuid:)
    AtlasRb::Metrics.latency(minutes: LatencyHistogram::WINDOW_MINUTES, nuid: nuid)
  rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("[atlas latency] Atlas's own figures unavailable: #{e.class}: #{e.message}")
    nil
  end
end
