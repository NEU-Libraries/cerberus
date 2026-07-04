# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifAssetsJob, type: :job do
  include ActiveJob::TestHelper

  let(:work_id) { 'w-123' }
  let(:tmp) { Dir.mktmpdir }
  let(:source_path) { File.join(tmp, 'image.png') }
  let(:open_base) { 'http://example.com/iiif/3/open.jp2' }
  let(:gated_base) { 'http://example.com/iiif/3/gated.jp2' }
  let(:result) { MasterJp2::Result.new(open_base: open_base, gated_base: gated_base) }

  before do
    File.write(source_path, 'fake bytes')
    allow(ThumbnailCreationJob).to receive(:perform_now)
    allow(DerivativeCreationJob).to receive(:perform_now)
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return([AtlasRb::Mash.new(noid: 'fs-1')])
    allow(AtlasRb::FileSet).to receive(:set_iiif_service)
  end

  after { FileUtils.rm_rf(tmp) }

  it 'thumbnails from the open base, sets the gated service, and derivatives from the gated base' do
    widths = { small: 320, medium: 640, large: 1280 }
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).with(path: source_path).and_return(result)

    expect(ThumbnailCreationJob).to receive(:perform_now).with(work_id, open_base).ordered
    expect(DerivativeCreationJob).to receive(:perform_now).with(work_id, gated_base, widths: widths).ordered

    described_class.new.perform(work_id, source_path, derivative_widths: widths)

    expect(AtlasRb::FileSet).to have_received(:set_iiif_service).with('fs-1', gated_base)
    expect(MasterJp2).to have_received(:call).with(path: source_path).once
  end

  it 'generates thumbnails + service only when no derivative_widths are passed (renditions are opt-in)' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).with(path: source_path).and_return(result)

    described_class.new.perform(work_id, source_path)

    expect(ThumbnailCreationJob).to have_received(:perform_now).with(work_id, open_base)
    expect(AtlasRb::FileSet).to have_received(:set_iiif_service).with('fs-1', gated_base)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end

  it 'noops when the work already has a thumbnail' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: 'already'))
    allow(MasterJp2).to receive(:call)

    described_class.new.perform(work_id, source_path)

    expect(MasterJp2).not_to have_received(:call)
    expect(ThumbnailCreationJob).not_to have_received(:perform_now)
    expect(AtlasRb::FileSet).not_to have_received(:set_iiif_service)
  end

  it 'discards with a warning when vips cannot read the source (broken/encrypted PDF)' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).and_raise(Vips::Error, 'unsupported file format')
    allow(Rails.logger).to receive(:warn)

    expect do
      perform_enqueued_jobs { described_class.perform_later(work_id, source_path) }
    end.not_to raise_error

    expect(Rails.logger).to have_received(:warn).with(/thumbnails skipped/)
    expect(ThumbnailCreationJob).not_to have_received(:perform_now)
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
