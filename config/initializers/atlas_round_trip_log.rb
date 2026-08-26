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
  Rails.application.config.after_initialize do
    buffer = []
    lock = Mutex.new
    flag = Rails.root.join('tmp/atlas-trips.on')

    ActiveSupport::Notifications.subscribe('request.atlas_rb') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      lock.synchronize do
        buffer << { method: event.payload.method.to_s.upcase, path: event.payload.url.path,
                    ms: event.duration, start_ms: event.time.to_f * 1000 }
      end
    end

    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      calls = lock.synchronize { buffer.slice!(0..) }
      next if calls.empty? || !flag.exist?

      # Overlap is the summed duration of the calls minus the span they occupy end
      # to end. Summed well above elapsed means they genuinely ran concurrently;
      # roughly equal means they were serial, whoever serialised them.
      elapsed = calls.map { |call| call[:start_ms] + call[:ms] }.max - calls.map { |call| call[:start_ms] }.min
      summed = calls.sum { |call| call[:ms] }

      Rails.logger.info(
        format('[atlas-trips] %<label>s — %<count>d calls, %<summed>.1f ms summed, ' \
               '%<elapsed>.1f ms elapsed, page %<page>.1f ms',
               label: "#{event.payload[:method]} #{event.payload[:path]}", count: calls.size,
               summed: summed, elapsed: elapsed, page: event.duration)
      )
      calls.each do |call|
        Rails.logger.info(format('[atlas-trips]     %<m>-6s %<p>-58s %<ms>8.1f ms',
                                 m: call[:method], p: call[:path], ms: call[:ms]))
      end
    end
  end
end
