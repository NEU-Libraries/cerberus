# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThumbnailCreationJob, type: :job do
  let(:work_id) { 'w-123' }
  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }
  let(:urls) do
    {
      thumbnail:    "#{base}/full/!85,85/0/default.jpg",
      thumbnail_2x: "#{base}/full/!170,170/0/default.jpg",
      preview:      "#{base}/full/500,/0/default.jpg"
    }
  end

  it 'PATCHes the sized IIIF URIs via set_thumbnails' do
    allow(ThumbnailCreator).to receive(:call).with(base: base).and_return(urls)
    allow(AtlasRb::Work).to receive(:set_thumbnails)

    described_class.new.perform(work_id, base)

    expect(ThumbnailCreator).to have_received(:call).with(base: base)
    expect(AtlasRb::Work).to have_received(:set_thumbnails).with(
      work_id,
      thumbnail: urls[:thumbnail],
      thumbnail_2x: urls[:thumbnail_2x],
      preview: urls[:preview]
    )
  end
end
