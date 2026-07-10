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
