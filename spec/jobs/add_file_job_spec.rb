# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AddFileJob, type: :job do
  let(:source) { Rails.root.join('spec/fixtures/files/image.png').to_s }
  let(:key)    { 'idem-key-1' }

  describe '#perform' do
    it 'attaches the staged file as a new Blob on the Work' do
      allow(AtlasRb::Blob).to receive(:create)

      described_class.perform_now('w1', source, 'image.png', key)

      expect(AtlasRb::Blob).to have_received(:create).with('w1', source, 'image.png', idempotency_key: key)
    end

    # A Solid Queue retry can fire after the staged file is cleaned up; the job
    # must no-op rather than blow up (and Blob.create is idempotent regardless).
    it 'does nothing when the staged file is gone' do
      allow(AtlasRb::Blob).to receive(:create)

      described_class.perform_now('w1', '/nonexistent/path.bin', 'x.bin', key)

      expect(AtlasRb::Blob).not_to have_received(:create)
    end
  end
end
