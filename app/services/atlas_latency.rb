# frozen_string_literal: true

# Atlas round-trip times for the admin health page, fed by atlas_rb's
# request.atlas_rb event. See docs/outages.md.
module AtlasLatency
  # The health probes call this every few seconds whoever is watching, so
  # counting them would report the monitor's traffic as the app's.
  IGNORED_PATHS = %w[/health /up].freeze

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
end
