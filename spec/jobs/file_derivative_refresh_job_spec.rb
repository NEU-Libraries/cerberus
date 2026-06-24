# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileDerivativeRefreshJob do
  it 'downloads the current (reinstated) content and re-dispatches derivatives only' do
    allow(AtlasRb::Blob).to receive(:find).with('b1').and_return(OpenStruct.new(filename: 'image.png'))
    allow(AtlasRb::Blob).to receive(:content).with('b1').and_yield('PNGDATA')
    expect(IngestDispatch).to receive(:call).with(
      hash_including(work_id: 'w1', original_filename: 'image.png', include_primary: false)
    )

    described_class.perform_now('w1', 'b1')
  end

  it 'no-ops when the blob is gone' do
    allow(AtlasRb::Blob).to receive(:find).with('b1').and_return(nil)
    expect(IngestDispatch).not_to receive(:call)

    described_class.perform_now('w1', 'b1')
  end
end
