# frozen_string_literal: true

require 'rails_helper'

# Stubbed at the one method that reads the Solid Queue tables: the test
# environment runs the :test job adapter, so those tables do not exist here.
RSpec.describe JobQueueStats do
  let(:enqueued_at) { 25.minutes.ago }
  let(:tables) do
    { waiting_by_queue: { 'default' => 3, 'background' => 9 }, oldest_waiting_at: enqueued_at,
      running: 2, scheduled: 1, blocked: 0, failed: 4, workers: 1 }
  end

  before { allow(described_class).to receive(:read_tables).and_return(tables) }

  it 'counts what is waiting, by queue, in a stable order' do
    snapshot = described_class.call

    expect(snapshot.waiting_by_queue.keys).to eq %w[background default]
    expect(snapshot.waiting).to eq 12
  end

  it 'reports when the oldest waiting job was enqueued' do
    expect(described_class.call.oldest_waiting_at).to eq enqueued_at
  end

  it 'answers nil rather than raising when the queue database does not answer' do
    allow(described_class).to receive(:read_tables).and_raise(ActiveRecord::ConnectionNotEstablished)

    expect(described_class.call).to be_nil
  end
end
