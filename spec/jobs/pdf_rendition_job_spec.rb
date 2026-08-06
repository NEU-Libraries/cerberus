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
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return(
      [AtlasRb::Mash.new(assets: [AtlasRb::Mash.new(role: 'original_file', noid: 'b-1')])]
    )
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

  it 'enqueues full-text extraction from the rendition PDF (Office text path)' do
    expect { described_class.new.perform(work_id, staged_path, rendition_key) }
      .to have_enqueued_job(FullTextExtractionJob).with(work_id, pdf_path)
  end

  it 'skips re-conversion when a previous attempt already produced the rendition' do
    FileUtils.cp(fixtures.join('example.pdf'), pdf_path)

    described_class.new.perform(work_id, staged_path, rendition_key)

    expect(WordToPdf).not_to have_received(:call)
    expect(AtlasRb::Blob).to have_received(:create)
  end

  it 'raises PrimaryFileMissing while the primary Blob writer is still running (rides retry_on)' do
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return([])

    expect { described_class.new.perform(work_id, staged_path, rendition_key) }
      .to raise_error(described_class::PrimaryFileMissing)
    expect(AtlasRb::Blob).not_to have_received(:create)
    expect(IiifAssetsJob).not_to have_received(:perform_now)
  end

  # An unconfirmed deposit is in_progress indefinitely, so a wait keyed on that
  # flag would strand the rendition on a human rather than on the Blob writer.
  it 'attaches for a Work still awaiting its depositor, as long as the primary file is there' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(in_progress: true))

    described_class.new.perform(work_id, staged_path, rendition_key)

    expect(AtlasRb::Blob).to have_received(:create)
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

  # A log line was the only trace of this before: the deposit keeps its file and
  # stays readable, so nobody found out the document had no PDF version.
  it 'flags the work incomplete once it has given up' do
    allow(WordToPdf).to receive(:call).and_raise(Libreconv::ConversionFailedError, 'soffice exploded')
    allow(IncompleteFlag).to receive(:set)

    perform_enqueued_jobs { described_class.perform_later(work_id, staged_path, rendition_key) }

    expect(IncompleteFlag).to have_received(:set)
      .with(work_id, hash_including(reason: IncompleteReasons::PDF_RENDITION))
  end

  # The nuid has to come off the job instance. A give-up handler runs after
  # around_perform has unwound, so the ambient Current.nuid is gone by then and
  # Atlas has no principal to authenticate — which failed the write silently,
  # since IncompleteFlag swallows its own errors by design.
  it 'flags as the principal the job captured, not an ambient one' do
    allow(WordToPdf).to receive(:call).and_raise(Libreconv::ConversionFailedError, 'soffice exploded')
    allow(IncompleteFlag).to receive(:set)

    Current.set(nuid: '000000002') do
      perform_enqueued_jobs { described_class.perform_later(work_id, staged_path, rendition_key) }
    end

    expect(IncompleteFlag).to have_received(:set).with(work_id, hash_including(nuid: '000000002'))
  end

  it 'clears the flag on a run that succeeds, so a repaired work heals itself' do
    allow(IncompleteFlag).to receive(:clear)

    described_class.new.perform(work_id, staged_path, rendition_key)

    expect(IncompleteFlag).to have_received(:clear).with(work_id)
  end
end
