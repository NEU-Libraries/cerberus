# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThumbnailCreationJob, type: :job do
  let(:work_id) { 'w-123' }
  let(:image) { IiifImageCreator::Result.new(open_base: 'http://example.com/iiif/3/open-aaa.tif') }
  let(:arguments) { { thumbnail: 'T', thumbnail_2x: 'T2', preview: 'P', preview_width: 500, preview_height: 333 } }

  it 'PATCHes the thumbnail URLs and preview size via set_thumbnails' do
    allow(ThumbnailCreator).to receive(:call).with(image: image).and_return(arguments)
    allow(AtlasRb::Resource).to receive(:set_thumbnails)

    described_class.new.perform(work_id, image)

    expect(AtlasRb::Resource).to have_received(:set_thumbnails).with(work_id, **arguments)
  end
end
