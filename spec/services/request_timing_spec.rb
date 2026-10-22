# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RequestTiming do
  let(:timing) { described_class.new }

  it 'measures from the start of the first call to the end of the last' do
    timing.add_atlas_call(1000.0, 1040.0)
    timing.add_atlas_call(1050.0, 1080.0)

    expect(timing.atlas_elapsed_ms).to eq 80.0
  end

  # The Work page's four parallel reads: the person waits for the slowest, not
  # for the four added together.
  it 'counts calls that ran side by side once' do
    4.times { |i| timing.add_atlas_call(1000.0 + i, 1100.0 + i) }

    expect(timing.atlas_elapsed_ms).to eq 103.0
    expect(timing.atlas_calls).to eq 4
  end

  it 'reports no waiting for a request that made no calls' do
    expect(timing.atlas_elapsed_ms).to eq 0.0
  end

  # The mechanism the page figures rely on: ParallelAtlasReads copies Current
  # into each worker, and a copy of the attributes hash shares this object, so
  # calls made on worker threads reach the request's own timing.
  describe 'with ParallelAtlasReads' do
    let(:reader) { Class.new { include ParallelAtlasReads }.new }

    after { Current.reset }

    it 'collects calls made on the worker threads' do
      Current.request_timing = timing
      tasks = (0...4).index_with { |i| -> { Current.request_timing.add_atlas_call(1000.0 + i, 1100.0 + i) } }

      reader.send(:parallel_atlas_reads, tasks)

      expect(timing.atlas_calls).to eq 4
    end
  end
end
