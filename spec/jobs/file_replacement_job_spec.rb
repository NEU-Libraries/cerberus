# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileReplacementJob do
  let(:staged) { Rails.root.join('spec/fixtures/files/image.png').to_s }

  it 'replaces the blob bytes (NOID preserved) and re-dispatches derivative-only enrichment' do
    expect(AtlasRb::Blob).to receive(:update).with('b1', staged, idempotency_key: 'idem')
    expect(IngestDispatch).to receive(:call).with(
      work_id: 'w1', staged_path: staged, original_filename: 'image.png',
      idempotency_key: 'idem', include_primary: false
    )

    described_class.perform_now('b1', 'w1', staged, 'image.png', 'idem')
  end

  it 'no-ops when the staged file is missing (a swept retry, say)' do
    expect(AtlasRb::Blob).not_to receive(:update)
    expect(IngestDispatch).not_to receive(:call)

    described_class.perform_now('b1', 'w1', '/no/such/file.png', 'x.png', 'idem')
  end
end
