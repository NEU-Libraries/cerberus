# frozen_string_literal: true

require 'rails_helper'

# Calls #perform directly, like ConfirmDepositJob's spec: the retry_on rescue sits
# in the perform_now chain, so going through it would swallow the raise the
# primary-file guard exists to make.
RSpec.describe CaptionJob do
  let(:staged) { Rails.root.join('spec/fixtures/files/captions.vtt').to_s }

  def stub_work(assets, primary: true)
    roles = primary ? %w[original_file] : %w[thumbnail_image]
    file_sets = [AtlasRb::Mash.new(assets: roles.map { |role| AtlasRb::Mash.new(role: role, noid: 'b-1') })]
    allow(AtlasRb::Work).to receive(:file_sets).and_return(file_sets)
    allow(AtlasRb::Work).to receive(:assets).and_return(assets)
  end

  let(:video) { AtlasRb::Mash.new(noid: 'v-1', mime_type: 'video/mp4') }

  let(:english) { AtlasRb::Mash.new(noid: 'c-1', mime_type: 'text/vtt') }

  it 'creates the blob, with its language, when the work has no caption in it yet' do
    stub_work([video, english])
    expect(AtlasRb::Blob).to receive(:create)
      .with('w1', staged, 'es.vtt', language: 'es', track_label: 'Español', idempotency_key: 'idem')

    described_class.new.perform('w1', staged, 'es.vtt', 'idem', 'language' => 'es', 'track_label' => 'Español')
  end

  # One caption per language: a second upload rewrites the blob already there,
  # so the NOID every rendered page points at survives and the superseded file
  # stays in that blob's version history.
  it 'replaces the bytes of that language\'s caption rather than attaching a second' do
    stub_work([video, english])
    expect(AtlasRb::Blob).to receive(:update)
      .with('c-1', staged, language: 'en', track_label: 'English', idempotency_key: 'idem')
    expect(AtlasRb::Blob).not_to receive(:create)

    described_class.new.perform('w1', staged, 'captions.vtt', 'idem', 'language' => 'en', 'track_label' => 'English')
  end

  # A job queued before the form asked for a language carries four arguments.
  it 'treats a job queued without a language as English' do
    stub_work([video, english])
    expect(AtlasRb::Blob).to receive(:update)
      .with('c-1', staged, language: 'en', track_label: 'English', idempotency_key: 'idem')

    described_class.new.perform('w1', staged, 'captions.vtt', 'idem')
  end

  # The guard that keeps a deposit honest. Atlas gives a caption the same
  # `original_file` role as the video original, so a caption written first would
  # satisfy ConfirmDepositJob's primary-file wait and let the work complete — and
  # Atlas builds the METS structMap at completion, omitting the video.
  it 'writes nothing until the primary file has landed (rides retry_on)' do
    stub_work([], primary: false)
    expect(AtlasRb::Blob).not_to receive(:create)
    expect(AtlasRb::Blob).not_to receive(:update)

    expect { described_class.new.perform('w1', staged, 'captions.vtt', 'idem') }
      .to raise_error(described_class::PrimaryFileMissing)
  end

  it 'no-ops when the staged file is missing (a swept retry, say)' do
    expect(AtlasRb::Blob).not_to receive(:create)
    expect(AtlasRb::Work).not_to receive(:file_sets)

    described_class.new.perform('w1', '/no/such/file.vtt', 'captions.vtt', 'idem')
  end
end
