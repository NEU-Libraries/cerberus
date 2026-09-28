# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmbargoReleaseJob do
  it 'asks Atlas once to record the lapsed embargoes' do
    allow(AtlasRb::System).to receive(:release_embargoes).and_return(%w[w1 w2])

    described_class.perform_now

    expect(AtlasRb::System).to have_received(:release_embargoes).once.with(no_args)
  end

  # The next night's run catches up, so a maintenance window is not a failure
  # and must not be retried through.
  it 'returns quietly while Atlas is read-only' do
    allow(AtlasRb::System).to receive(:release_embargoes).and_raise(AtlasRb::ReadOnlyModeError)

    expect { described_class.perform_now }.not_to raise_error
    expect(described_class).not_to have_been_enqueued
  end
end
