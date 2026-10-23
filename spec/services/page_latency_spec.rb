# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PageLatency do
  let(:histogram) { instance_double(LatencyHistogram, record: nil) }

  before { allow(described_class).to receive(:histogram).and_return(histogram) }
  after { Current.reset }

  def event(controller: 'WorksController', action: 'show', method: 'GET', status: 200, duration: 310.0)
    payload = { controller: controller, action: action, method: method, status: status }
    instance_double(ActiveSupport::Notifications::Event, duration: duration, payload: payload)
  end

  describe '.record' do
    it "records a page's time with the part spent waiting on Atlas" do
      Current.request_timing = RequestTiming.new.tap { |timing| timing.add_atlas_call(0.0, 220.0) }

      described_class.record(event)

      expect(described_class).to have_received(:histogram).with('works#show')
      expect(histogram).to have_received(:record).with(310.0, sums: { atlas_ms: 220.0 })
    end

    it 'records a page that made no Atlas calls as no waiting' do
      described_class.record(event(controller: 'CatalogController', action: 'index'))

      expect(histogram).to have_received(:record).with(310.0, sums: { atlas_ms: 0 })
    end

    it 'leaves out a page that is not on the list' do
      described_class.record(event(controller: 'Admin::HealthController'))

      expect(histogram).not_to have_received(:record)
    end

    # An error page's time says nothing about how long the page itself takes.
    it 'leaves out errors and writes' do
      described_class.record(event(status: 503))
      described_class.record(event(method: 'POST'))

      expect(histogram).not_to have_received(:record)
    end
  end

  describe '.rows' do
    def summary(calls:, mean: 310, atlas: 220)
      LatencyHistogram::Summary.new(calls: calls, mean_ms: mean, p50_ms: 290, p95_ms: 520,
                                    p99_ms: 700, extra_means: { atlas_ms: atlas })
    end

    it 'gives each viewed page in the fixed order, with the rest of the mean beside Atlas' do
      allow(histogram).to receive(:summary).and_return(summary(calls: 0))
      allow(described_class).to receive(:histogram).with('works#show')
                                                   .and_return(instance_double(LatencyHistogram, summary: summary(calls: 412)))

      rows = described_class.rows

      expect(rows.map(&:label)).to eq ['Work page']
      expect(rows.first.to_h).to include(views: 412, usual_ms: 290, slow_ms: 520, atlas_mean_ms: 220)
      expect(rows.first.page_mean_ms).to eq 90
    end

    it 'answers nil when Redis did not answer, rather than an empty table' do
      allow(histogram).to receive(:summary).and_return(nil)

      expect(described_class.rows).to be_nil
    end
  end
end
