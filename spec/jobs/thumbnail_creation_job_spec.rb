# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThumbnailCreationJob, type: :job do
  let(:work_id) { 'w-123' }
  let(:tmp) { Dir.mktmpdir }
  let(:source_path) { File.join(tmp, 'image.png') }

  before { File.write(source_path, 'fake bytes') }
  after  { FileUtils.remove_entry(tmp) if File.exist?(tmp) }

  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }
  let(:urls) do
    {
      'thumbnail'    => "#{base}/full/!85,85/0/default.jpg",
      'thumbnail_2x' => "#{base}/full/!170,170/0/default.jpg",
      'preview'      => "#{base}/full/500,/0/default.jpg"
    }
  end

  it 'generates the JP2 and PATCHes the sized IIIF URIs via set_thumbnails' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).with(path: source_path).and_return(base)
    allow(ThumbnailCreator).to receive(:call).with(base: base).and_return(urls)
    allow(AtlasRb::Work).to receive(:set_thumbnails)

    described_class.new.perform(work_id, source_path)

    expect(MasterJp2).to have_received(:call).with(path: source_path)
    expect(ThumbnailCreator).to have_received(:call).with(base: base)
    expect(AtlasRb::Work).to have_received(:set_thumbnails).with(
      work_id,
      thumbnail: urls['thumbnail'],
      thumbnail_2x: urls['thumbnail_2x'],
      preview: urls['preview']
    )
  end

  it 'noops when the work already has a thumbnail' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: 'already'))
    allow(MasterJp2).to receive(:call)
    allow(ThumbnailCreator).to receive(:call)
    allow(AtlasRb::Work).to receive(:set_thumbnails)

    described_class.new.perform(work_id, source_path)

    expect(MasterJp2).not_to have_received(:call)
    expect(ThumbnailCreator).not_to have_received(:call)
    expect(AtlasRb::Work).not_to have_received(:set_thumbnails)
  end

  it 'noops when the staged file is missing' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call)
    allow(ThumbnailCreator).to receive(:call)
    allow(AtlasRb::Work).to receive(:set_thumbnails)
    File.delete(source_path)

    described_class.new.perform(work_id, source_path)

    expect(MasterJp2).not_to have_received(:call)
    expect(ThumbnailCreator).not_to have_received(:call)
    expect(AtlasRb::Work).not_to have_received(:set_thumbnails)
  end
end
