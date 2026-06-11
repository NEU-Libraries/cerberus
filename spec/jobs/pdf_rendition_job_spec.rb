# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfRenditionJob, type: :job do
  include ActiveJob::TestHelper

  let(:work_id) { 'w-word' }
  let(:tmp) { Dir.mktmpdir }
  let(:staged_path) { File.join(tmp, 'thesis.docx') }
  let(:pdf_path) { File.join(tmp, 'thesis.pdf') }
  let(:rendition_key) { 'rk-123' }
  let(:fixtures) { Rails.root.join('spec/fixtures/files') }

  before do
    FileUtils.cp(fixtures.join('example.docx'), staged_path)
    allow(WordToPdf).to receive(:available?).and_return(true)
    allow(WordToPdf).to receive(:call) { FileUtils.cp(fixtures.join('example.pdf'), pdf_path) }
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(in_progress: false))
    allow(AtlasRb::Blob).to receive(:create)
    allow(IiifAssetsJob).to receive(:perform_now)
  end

  after { FileUtils.rm_rf(tmp) }

  it 'converts, attaches <basename>.pdf with the rendition key, then seeds thumbnails from the rendition' do
    described_class.new.perform(work_id, staged_path, rendition_key)

    expect(WordToPdf).to have_received(:call).with(source_path: staged_path, target_path: pdf_path)
    expect(AtlasRb::Blob).to have_received(:create)
      .with(work_id, pdf_path, 'thesis.pdf', idempotency_key: rendition_key)
    expect(IiifAssetsJob).to have_received(:perform_now).with(work_id, pdf_path)
  end

  it 'skips re-conversion when a previous attempt already produced the rendition' do
    FileUtils.cp(fixtures.join('example.pdf'), pdf_path)

    described_class.new.perform(work_id, staged_path, rendition_key)

    expect(WordToPdf).not_to have_received(:call)
    expect(AtlasRb::Blob).to have_received(:create)
  end

  it 'raises WorkNotComplete while the primary Blob writer is still running (rides retry_on)' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(in_progress: true))

    expect { described_class.new.perform(work_id, staged_path, rendition_key) }
      .to raise_error(described_class::WorkNotComplete)
    expect(AtlasRb::Blob).not_to have_received(:create)
    expect(IiifAssetsJob).not_to have_received(:perform_now)
  end

  it 'warns and skips on images built without LibreOffice (deposit untouched)' do
    allow(WordToPdf).to receive(:available?).and_return(false)
    allow(Rails.logger).to receive(:warn)

    described_class.new.perform(work_id, staged_path, rendition_key)

    expect(Rails.logger).to have_received(:warn).with(/soffice not installed/)
    expect(WordToPdf).not_to have_received(:call)
    expect(AtlasRb::Blob).not_to have_received(:create)
  end

  it 'noops when the staged file is missing' do
    File.delete(staged_path)

    described_class.new.perform(work_id, staged_path, rendition_key)

    expect(WordToPdf).not_to have_received(:call)
    expect(AtlasRb::Blob).not_to have_received(:create)
  end

  it 'logs and swallows when conversion keeps failing (deposit untouched)' do
    allow(WordToPdf).to receive(:call).and_raise(Libreconv::ConversionFailedError, 'soffice exploded')
    allow(Rails.logger).to receive(:warn)

    expect do
      perform_enqueued_jobs { described_class.perform_later(work_id, staged_path, rendition_key) }
    end.not_to raise_error

    expect(Rails.logger).to have_received(:warn).with(/gave up for work w-word/)
    expect(AtlasRb::Blob).not_to have_received(:create)
  end
end
