# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SafeSubscriber do
  let(:event_name) { "safe_subscriber_spec.#{SecureRandom.hex(4)}" }
  let(:subscribers) { [] }

  after { subscribers.each { |subscriber| ActiveSupport::Notifications.unsubscribe(subscriber) } }

  def instrument = ActiveSupport::Notifications.instrument(event_name) { :done }

  # Why the guard exists: ActiveSupport hands a subscriber's error back to the
  # code being instrumented. This is what failed every Atlas call when a
  # running server's subscriber named a constant that had been removed.
  it 'is needed, because a plain subscriber that raises fails the instrumented call' do
    subscribers << ActiveSupport::Notifications.subscribe(event_name) { raise NameError, 'AtlasLatency' }

    expect { instrument }.to raise_error(NameError)
  end

  it 'lets the instrumented call finish when the block raises' do
    subscribers << described_class.subscribe(event_name, label: 'spec') { raise NameError, 'AtlasLatency' }

    expect(instrument).to eq :done
  end

  it 'logs the failure, naming the subscriber' do
    allow(Rails.logger).to receive(:warn)
    subscribers << described_class.subscribe(event_name, label: 'page latency') { raise ArgumentError, 'bad' }

    instrument

    expect(Rails.logger).to have_received(:warn).with(/\[page latency\].*ArgumentError: bad/)
  end

  it 'passes the event to the block' do
    seen = nil
    subscribers << described_class.subscribe(event_name, label: 'spec') { |event| seen = event.name }

    instrument

    expect(seen).to eq event_name
  end
end
