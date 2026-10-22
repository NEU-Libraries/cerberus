# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AtlasLatency do
  let(:histogram) { instance_double(LatencyHistogram, record: nil) }

  before { allow(described_class).to receive(:histogram).and_return(histogram) }

  def event(path: '/works/abc', status: 200, exception: nil, duration: 42.0)
    env = Faraday::Env.new.tap do |faraday_env|
      faraday_env.url = URI("http://atlas:3000#{path}")
      faraday_env.status = status
      faraday_env[:exception_object] = exception if exception
    end
    instance_double(ActiveSupport::Notifications::Event, payload: env, duration: duration,
                                                         time: 10.0, end: 10.0 + (duration / 1000))
  end

  it 'records a call with its duration' do
    described_class.record(event)

    expect(histogram).to have_received(:record).with(42.0, failed: false, timeout: false)
  end

  it 'counts a 5xx as failed' do
    described_class.record(event(status: 503))

    expect(histogram).to have_received(:record).with(42.0, failed: true, timeout: false)
  end

  it 'counts a timeout as failed and as a timeout' do
    described_class.record(event(status: nil, exception: Faraday::TimeoutError.new))

    expect(histogram).to have_received(:record).with(42.0, failed: true, timeout: true)
  end

  it "adds the call to the request's own timing" do
    Current.request_timing = RequestTiming.new
    described_class.record(event)

    expect(Current.request_timing.atlas_elapsed_ms).to be_within(0.001).of(42.0)
  ensure
    Current.reset
  end

  # The health probes run whoever is watching, so they are the monitor's
  # traffic, not the app's.
  it 'leaves the health probes out' do
    described_class.record(event(path: '/health'))

    expect(histogram).not_to have_received(:record)
  end

  # The admin page reads it on every load, so counting it would report the
  # page's own traffic.
  it "leaves the read of Atlas's own figures out" do
    described_class.record(event(path: '/metrics/latency'))

    expect(histogram).not_to have_received(:record)
  end

  describe '.served' do
    it "asks Atlas for the same window Cerberus's figures cover" do
      allow(AtlasRb::Metrics).to receive(:latency).and_return(AtlasRb::Mash.new('calls' => 1))

      described_class.served(nuid: '000000004')

      expect(AtlasRb::Metrics).to have_received(:latency)
        .with(minutes: LatencyHistogram::WINDOW_MINUTES, nuid: '000000004')
    end

    # Its Redis down, a non-admin refused, or Atlas gone: the page shows the
    # row as unavailable rather than failing.
    [AtlasRb::BackendUnavailableError.new(dependency: 'cache'),
     AtlasRb::ResourceError.new('403'), Faraday::ConnectionFailed.new('refused')].each do |error|
      it "answers nil when Atlas raises #{error.class}" do
        allow(AtlasRb::Metrics).to receive(:latency).and_raise(error)

        expect(described_class.served(nuid: '000000004')).to be_nil
      end
    end
  end
end
