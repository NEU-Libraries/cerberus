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
    instance_double(ActiveSupport::Notifications::Event, payload: env, duration: duration)
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

  # The health probes run whoever is watching, so they are the monitor's
  # traffic, not the app's.
  it 'leaves the health probes out' do
    described_class.record(event(path: '/health'))

    expect(histogram).not_to have_received(:record)
  end
end
