# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeCreationJob, type: :job do
  let(:work_id) { 'w-123' }
  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }
  let(:urls) do
    {
      small:  "#{base}/full/pct:33/0/default.jpg",
      medium: "#{base}/full/pct:50/0/default.jpg",
      large:  "#{base}/full/pct:75/0/default.jpg"
    }
  end

  it 'PATCHes the sized IIIF URIs via set_image_derivatives' do
    allow(DerivativeCreator).to receive(:call).with(base: base, widths: nil).and_return(urls)
    allow(AtlasRb::Work).to receive(:set_image_derivatives)

    described_class.new.perform(work_id, base)

    expect(DerivativeCreator).to have_received(:call).with(base: base, widths: nil)
    expect(AtlasRb::Work).to have_received(:set_image_derivatives).with(
      work_id,
      small: urls[:small],
      medium: urls[:medium],
      large: urls[:large]
    )
  end

  it 'forwards caller-supplied widths to DerivativeCreator' do
    widths = { small: 320, medium: 640, large: 1280 }
    allow(DerivativeCreator).to receive(:call).with(base: base, widths: widths).and_return(urls)
    allow(AtlasRb::Work).to receive(:set_image_derivatives)

    described_class.new.perform(work_id, base, widths: widths)

    expect(DerivativeCreator).to have_received(:call).with(base: base, widths: widths)
  end
end
