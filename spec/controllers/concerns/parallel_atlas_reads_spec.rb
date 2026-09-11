# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParallelAtlasReads do
  # The concern is a private controller helper; exercise it through a bare
  # includer rather than booting a controller.
  let(:host) do
    Class.new do
      include ParallelAtlasReads

      def run(tasks) = parallel_atlas_reads(tasks)
    end.new
  end

  it 'returns each task result keyed as given' do
    expect(host.run(a: -> { 1 }, b: -> { 2 })).to eq(a: 1, b: 2)
  end

  it 'handles an empty batch' do
    expect(host.run({})).to eq({})
  end

  it 'runs a single task inline on the caller thread (no thread spawned)' do
    caller_thread = Thread.current
    ran_on = nil
    host.run(only: -> { ran_on = Thread.current })
    expect(ran_on).to eq(caller_thread)
  end

  it 'propagates Current into worker threads (atlas_rb auth reads Current.nuid)' do
    Current.nuid = '000000009'
    # Two tasks force the threaded path — a single task would run inline and see
    # Current trivially.
    expect(host.run(one: -> { Current.nuid }, two: -> { Current.nuid }))
      .to eq(one: '000000009', two: '000000009')
  ensure
    Current.reset
  end

  it 'runs the tasks concurrently' do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    host.run(a: -> { sleep 0.1 }, b: -> { sleep 0.1 }, c: -> { sleep 0.1 })
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    # Serial would be ~0.3s; concurrent is ~0.1s. Ceiling leaves room for jitter.
    expect(elapsed).to be < 0.25
  end

  # The thread the event is raised on is the load-bearing part, not the name:
  # ActionDispatch::ServerTiming keeps its collection per-thread, so an event
  # from a worker is dropped and the batch stays invisible.
  describe 'instrumentation' do
    def capture_batch_events(&block)
      seen = []
      subscriber = ->(event) { seen << { event: event, thread: Thread.current } }
      ActiveSupport::Notifications.subscribed(subscriber, described_class::INSTRUMENTATION_EVENT, &block)
      seen
    end

    it 'reports the threaded batch as one event on the caller thread' do
      caller_thread = Thread.current
      seen = capture_batch_events { host.run(a: -> { sleep 0.05 }, b: -> { sleep 0.05 }) }

      expect(seen.length).to eq(1)
      expect(seen.first[:thread]).to eq(caller_thread)
      expect(seen.first[:event].payload[:count]).to eq(2)
    end

    it 'times the whole batch, not the call that starts it' do
      seen = capture_batch_events { host.run(a: -> { sleep 0.05 }, b: -> { sleep 0.05 }) }

      # Concurrent, so the batch is ~50ms rather than ~100ms. The floor only has
      # to prove the event spans the work instead of closing immediately.
      expect(seen.first[:event].duration).to be > 40
    end

    it 'does not wrap the inline single-task path, which atlas_rb already times' do
      expect(capture_batch_events { host.run(only: -> { 1 }) }).to be_empty
    end

    it 'still reports the batch when a task raises' do
      seen = []
      subscriber = ->(event) { seen << event }
      ActiveSupport::Notifications.subscribed(subscriber, described_class::INSTRUMENTATION_EVENT) do
        expect { host.run(ok: -> { 1 }, bad: -> { raise 'nope' }) }.to raise_error('nope')
      end

      expect(seen.length).to eq(1)
    end
  end

  it 're-raises a task error with its class and message' do
    boom = Class.new(StandardError)
    expect { host.run(ok: -> { 1 }, bad: -> { raise boom, 'nope' }) }
      .to raise_error(boom, 'nope')
  end

  it 'still raises when an earlier task fails and a later one succeeds' do
    expect { host.run(bad: -> { raise 'first' }, ok: -> { sleep 0.05 }) }
      .to raise_error('first')
  end
end
