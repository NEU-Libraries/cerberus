# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContentCreationJob, type: :job do
  let(:work_id) { 'w-456' }
  let(:original_filename) { 'image.png' }
  let(:idempotency_key) { SecureRandom.uuid }
  let(:tmp) { Dir.mktmpdir }
  let(:source_path) { File.join(tmp, original_filename) }

  before { File.write(source_path, 'fake bytes') }
  after  { FileUtils.remove_entry(tmp) if File.exist?(tmp) }

  it 'uploads the blob with the supplied idempotency_key and marks the work complete' do
    allow(AtlasRb::Blob).to receive(:create)
    allow(AtlasRb::Work).to receive(:complete)

    described_class.new.perform(work_id, source_path, original_filename, idempotency_key)

    expect(AtlasRb::Blob).to have_received(:create)
      .with(work_id, source_path, original_filename, idempotency_key: idempotency_key)
    expect(AtlasRb::Work).to have_received(:complete).with(work_id)
  end

  it 'noops when the staged file is missing' do
    allow(AtlasRb::Blob).to receive(:create)
    allow(AtlasRb::Work).to receive(:complete)
    File.delete(source_path)

    described_class.new.perform(work_id, source_path, original_filename, idempotency_key)

    expect(AtlasRb::Blob).not_to have_received(:create)
    expect(AtlasRb::Work).not_to have_received(:complete)
  end
end
