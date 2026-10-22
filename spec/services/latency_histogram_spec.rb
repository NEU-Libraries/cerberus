# frozen_string_literal: true

require 'rails_helper'

# Against the stack's real Redis, under a name of its own, so the examples
# neither see nor leave anything behind.
RSpec.describe LatencyHistogram do
  let(:histogram) { described_class.new("spec-#{SecureRandom.hex(4)}") }

  before { described_class.resume! }

  after do
    described_class.resume!
    described_class.redis.del(*histogram.keys)
  end

  it 'counts calls, failures and timeouts across the window' do
    histogram.record(12)
    histogram.record(40, failed: true)
    histogram.record(9000, failed: true, timeout: true)

    summary = histogram.summary

    expect(summary.to_h.slice(:calls, :failed, :timeouts)).to eq(calls: 3, failed: 2, timeouts: 1)
    expect(summary.mean_ms).to eq 3017
  end

  # Interpolated inside the bucket holding the rank, so these are not the exact
  # samples, only close to them.
  it 'interpolates percentiles from the buckets' do
    95.times { histogram.record(20) }
    5.times { histogram.record(800) }

    summary = histogram.summary

    expect(summary.p50_ms).to be_between(10, 25)
    expect(summary.p95_ms).to be_between(10, 25)
    expect(summary.p99_ms).to be_between(500, 1000)
  end

  it 'reports a call slower than every bucket at the last edge' do
    histogram.record(60_000)

    expect(histogram.summary.p99_ms).to eq described_class::BUCKETS_MS.last
  end

  # Means add up where percentiles do not, which is what lets the page table
  # split a page's average into waiting on Atlas and the rest.
  it 'reports the mean of each extra figure recorded with a call' do
    histogram.record(300, sums: { atlas_ms: 200 })
    histogram.record(100, sums: { atlas_ms: 40 })

    expect(histogram.summary.extra_means).to eq(atlas_ms: 120)
  end

  it 'reports no percentiles for an empty window' do
    expect(histogram.summary.to_h).to include(calls: 0, mean_ms: nil, p95_ms: nil)
  end

  # Every worker writes to the same key, which is the point of keeping this in
  # Redis rather than in process memory.
  it 'adds a second instance to the same figures' do
    histogram.record(30)
    described_class.new(histogram.instance_variable_get(:@name)).record(30)

    expect(histogram.summary.calls).to eq 2
  end

  describe 'when Redis does not answer' do
    before { allow(described_class.redis).to receive(:pipelined).and_raise(Redis::CannotConnectError) }

    it 'drops the write rather than failing the call it was timing' do
      expect { histogram.record(10) }.not_to raise_error
    end

    # Each write would otherwise wait out the connect timeout, on every
    # Atlas call, for as long as Redis is down.
    it 'stops trying for a while after a failure' do
      histogram.record(10)
      histogram.record(10)

      expect(described_class.redis).to have_received(:pipelined).once
    end

    it 'reports no summary rather than zeros' do
      expect(histogram.summary).to be_nil
    end
  end
end
