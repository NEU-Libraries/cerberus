# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifAssetsJob, type: :job do
  let(:work_id) { 'w-123' }
  let(:tmp) { Dir.mktmpdir }
  let(:source_path) { File.join(tmp, 'image.png') }
  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }

  before do
    File.write(source_path, 'fake bytes')
    allow(ThumbnailCreationJob).to receive(:perform_now)
    allow(DerivativeCreationJob).to receive(:perform_now)
  end

  after { FileUtils.rm_rf(tmp) }

  it 'writes the JP2 once and runs the thumbnail and derivative jobs serially' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).with(path: source_path).and_return(base)

    expect(ThumbnailCreationJob).to receive(:perform_now).with(work_id, base).ordered
    expect(DerivativeCreationJob).to receive(:perform_now).with(work_id, base, widths: nil).ordered

    described_class.new.perform(work_id, source_path)

    expect(MasterJp2).to have_received(:call).with(path: source_path).once
  end

  it 'forwards derivative_widths through to DerivativeCreationJob' do
    widths = { small: 320, medium: 640, large: 1280 }
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).with(path: source_path).and_return(base)

    described_class.new.perform(work_id, source_path, derivative_widths: widths)

    expect(DerivativeCreationJob).to have_received(:perform_now).with(work_id, base, widths: widths)
  end

  it 'noops when the work already has a thumbnail' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: 'already'))
    allow(MasterJp2).to receive(:call)

    described_class.new.perform(work_id, source_path)

    expect(MasterJp2).not_to have_received(:call)
    expect(ThumbnailCreationJob).not_to have_received(:perform_now)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end

  it 'noops when the staged file is missing' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call)
    File.delete(source_path)

    described_class.new.perform(work_id, source_path)

    expect(MasterJp2).not_to have_received(:call)
    expect(ThumbnailCreationJob).not_to have_received(:perform_now)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end
end
