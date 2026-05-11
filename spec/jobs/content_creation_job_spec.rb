# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContentCreationJob, type: :job do
  let(:work_id) { 'w-456' }
  let(:original_filename) { 'image.png' }
  let(:tmp) { Dir.mktmpdir }
  let(:source_path) { File.join(tmp, original_filename) }

  before { File.write(source_path, 'fake bytes') }
  after  { FileUtils.remove_entry(tmp) if File.exist?(tmp) }

  it 'uploads the blob when the work has no matching file yet' do
    allow(AtlasRb::Work).to receive(:files).with(work_id).and_return([])
    allow(AtlasRb::Blob).to receive(:create)

    described_class.new.perform(work_id, source_path, original_filename)

    expect(AtlasRb::Blob).to have_received(:create).with(work_id, source_path, original_filename)
  end

  it 'noops when the work already has a file with the same original_filename' do
    existing = AtlasRb::Mash.new(original_filename: original_filename)
    allow(AtlasRb::Work).to receive(:files).with(work_id).and_return([existing])
    allow(AtlasRb::Blob).to receive(:create)

    described_class.new.perform(work_id, source_path, original_filename)

    expect(AtlasRb::Blob).not_to have_received(:create)
  end

  it 'noops when the staged file is missing' do
    allow(AtlasRb::Work).to receive(:files).with(work_id).and_return([])
    allow(AtlasRb::Blob).to receive(:create)
    File.delete(source_path)

    described_class.new.perform(work_id, source_path, original_filename)

    expect(AtlasRb::Blob).not_to have_received(:create)
  end
end
