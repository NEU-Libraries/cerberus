# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThumbnailCreationJob, type: :job do
  let(:work_id) { 'w-123' }
  let(:tmp) { Dir.mktmpdir }
  let(:source_path) { File.join(tmp, 'image.png') }

  before { File.write(source_path, 'fake bytes') }
  after  { FileUtils.remove_entry(tmp) if File.exist?(tmp) }

  it 'creates the thumbnail and writes the IIIF URL to Work metadata' do
    thumbnail_url = 'http://example.com/iiif/3/uuid-abc.jp2'
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(ThumbnailCreator).to receive(:call).with(path: source_path).and_return(thumbnail_url)
    allow(AtlasRb::Work).to receive(:metadata)

    described_class.new.perform(work_id, source_path)

    expect(ThumbnailCreator).to have_received(:call).with(path: source_path)
    expect(AtlasRb::Work).to have_received(:metadata).with(work_id, 'thumbnail' => thumbnail_url)
  end

  it 'noops when the work already has a thumbnail' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: 'already'))
    allow(ThumbnailCreator).to receive(:call)
    allow(AtlasRb::Work).to receive(:metadata)

    described_class.new.perform(work_id, source_path)

    expect(ThumbnailCreator).not_to have_received(:call)
    expect(AtlasRb::Work).not_to have_received(:metadata)
  end

  it 'noops when the staged file is missing' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(ThumbnailCreator).to receive(:call)
    allow(AtlasRb::Work).to receive(:metadata)
    File.delete(source_path)

    described_class.new.perform(work_id, source_path)

    expect(ThumbnailCreator).not_to have_received(:call)
    expect(AtlasRb::Work).not_to have_received(:metadata)
  end
end
