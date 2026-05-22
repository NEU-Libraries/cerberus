# frozen_string_literal: true

require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job

RSpec.describe IiifAssetsJob, type: :job do
  include ActiveJob::TestHelper

  let(:work_id) { 'w-123' }
  let(:tmp) { Dir.mktmpdir }
  let(:source_path) { File.join(tmp, 'image.png') }
  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }

  before { File.write(source_path, 'fake bytes') }
  after  { FileUtils.rm_rf(tmp) }

  it 'writes the JP2 once and fans out to the thumbnail and derivative jobs' do
    allow(AtlasRb::Work).to receive(:find).with(work_id, nuid: '000000004').and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).with(path: source_path).and_return(base)

    expect do
      described_class.new.perform(work_id, source_path)
    end.to have_enqueued_job(ThumbnailCreationJob).with(work_id, base)
       .and have_enqueued_job(DerivativeCreationJob).with(work_id, base, widths: nil)

    expect(MasterJp2).to have_received(:call).with(path: source_path).once
  end

  it 'forwards derivative_widths through to DerivativeCreationJob' do
    widths = { small: 320, medium: 640, large: 1280 }
    allow(AtlasRb::Work).to receive(:find).with(work_id, nuid: '000000004').and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call).with(path: source_path).and_return(base)

    expect do
      described_class.new.perform(work_id, source_path, derivative_widths: widths)
    end.to have_enqueued_job(DerivativeCreationJob).with(work_id, base, widths: widths)
  end

  it 'noops when the work already has a thumbnail' do
    allow(AtlasRb::Work).to receive(:find).with(work_id, nuid: '000000004').and_return(AtlasRb::Mash.new(thumbnail: 'already'))
    allow(MasterJp2).to receive(:call)

    expect do
      described_class.new.perform(work_id, source_path)
    end.to not_have_enqueued_job(ThumbnailCreationJob)
       .and not_have_enqueued_job(DerivativeCreationJob)

    expect(MasterJp2).not_to have_received(:call)
  end

  it 'noops when the staged file is missing' do
    allow(AtlasRb::Work).to receive(:find).with(work_id, nuid: '000000004').and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(MasterJp2).to receive(:call)
    File.delete(source_path)

    expect do
      described_class.new.perform(work_id, source_path)
    end.to not_have_enqueued_job(ThumbnailCreationJob)
       .and not_have_enqueued_job(DerivativeCreationJob)

    expect(MasterJp2).not_to have_received(:call)
  end
end
