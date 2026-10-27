# frozen_string_literal: true

# Opt-in profiling aid: log every request's Atlas round-trips to the Rails log.
#
# atlas_rb emits a `request.atlas_rb` notification per outbound call (see
# AtlasRb::FaradayHelper). The harness in
# spec/integration/atlas_roundtrip_profile_spec.rb subscribes to it inside the
# test environment; this does the same in a running server, which is the only way
# to profile the *development* stack — the harness cannot be pointed at a dev
# Atlas, because the suite reseeds whatever ATLAS_URL names.
#
# Development only, and silent until the flag file exists:
#
#   touch tmp/atlas-trips.on    # start logging
#   rm    tmp/atlas-trips.on    # stop
#
# The flag is read per request rather than at boot so it toggles without a
# restart. When off, the subscriber still buffers a hash per call and drops it —
# cheap, and it keeps the toggle instant.
#
# **It aggregates globally, not per request.** A Work show page fans its reads out
# across threads (ParallelAtlasReads), and a thread-local accumulator would miss
# them, because the worker threads are where the calls happen. One mutex-guarded
# buffer catches them, at the cost of being accurate only while the server handles
# one request at a time. That holds when driving pages by hand to take
# measurements, which is what this is for; under concurrent traffic the
# attribution blurs.
if Rails.env.development?
  # Atlas's own view of the same call, from the headers it sends back: x-runtime
  # is its whole Rails stack, and Server-Timing's process_action is the action
  # alone, which is what its /metrics/latency reports. Cerberus's time minus
  # x-runtime is what happened outside Atlas's Rails app.
  atlas_timings = lambda do |headers|
    runtime = headers['x-runtime']
    action = headers['server-timing'].to_s[/process_action\.action_controller;dur=([\d.]+)/, 1]
    { rails_ms: runtime && (runtime.to_f * 1000), action_ms: action&.to_f }
  end

  shown = ->(ms) { ms ? format('%.1f', ms) : '-' }
  trip_line = lambda do |call|
    format('[atlas-trips]     %<m>-6s %<p>-58s %<ms>8.1f ms   atlas rails %<rails>s, action %<action>s',
           m: call[:method], p: call[:path], ms: call[:ms], rails: shown.call(call[:rails_ms]),
           action: shown.call(call[:action_ms]))
  end

  # Overlap is the summed duration of the calls minus the span they occupy end
  # to end. Summed well above elapsed means they genuinely ran concurrently;
  # roughly equal means they were serial, whoever serialised them.
  summary_line = lambda do |event, calls|
    elapsed = calls.map { |call| call[:start_ms] + call[:ms] }.max - calls.pluck(:start_ms).min
    format('[atlas-trips] %<label>s — %<count>d calls, %<summed>.1f ms summed, %<elapsed>.1f ms elapsed, ' \
           'page %<page>.1f ms',
           label: "#{event.payload[:method]} #{event.payload[:path]}", count: calls.size,
           summed: calls.sum { |call| call[:ms] }, elapsed: elapsed, page: event.duration)
  end

  # Both subscribers rescue their own errors. ActiveSupport re-raises a
  # subscriber's error into the instrumented code, so a fault in a profiling aid
  # would otherwise fail the Atlas call, or the page, it was watching.
  Rails.application.config.after_initialize do
    buffer = []
    lock = Mutex.new
    flag = Rails.root.join('tmp/atlas-trips.on')

    ActiveSupport::Notifications.subscribe('request.atlas_rb') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      timings = atlas_timings.call(event.payload.response_headers || {})
      lock.synchronize do
        buffer << { method: event.payload.method.to_s.upcase, path: event.payload.url.path,
                    ms: event.duration, start_ms: event.time.to_f * 1000, **timings }
      end
    rescue StandardError => e
      Rails.logger.warn("[atlas-trips] #{e.class}: #{e.message}")
    end

    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      # The compose healthcheck polls /up every 30 seconds, and it makes no Atlas
      # calls; flushing on it would hand it the page in flight's calls.
      next if event.payload[:path] == '/up'

      calls = lock.synchronize { buffer.slice!(0..) }
      next if calls.empty? || !flag.exist?

      Rails.logger.info(summary_line.call(event, calls))
      calls.each { |call| Rails.logger.info(trip_line.call(call)) }
    rescue StandardError => e
      Rails.logger.warn("[atlas-trips] #{e.class}: #{e.message}")
    end
  end
end
