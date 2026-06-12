# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageIngestJob, type: :job do
  let(:loader) { create(:loader, :multipage) }
  let(:load_report) do
    LoadReport.create!(loader: loader, parent_collection_id: 'col-abc',
                       source_filename: 'postcard.zip', status: :processing)
  end
  let(:ingest) do
    MultipageIngest.create!(load_report: load_report, source_filename: 'page2.tif',
                            sequence: 2, work_pid: 'w-1', idempotency_key: 'idem-2')
  end

  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:extracted_path) { File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted', 'page2.tif') }
  let(:staged_path) { File.join(uploads_root, 'w-1', 'page2.tif') }

  before do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(staged_path).and_return(false)
    allow(File).to receive(:exist?).with(extracted_path).and_return(true)
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:mv)
    allow(AtlasRb::FileSet).to receive(:create).and_return(double(id: 'fs-2'))
    allow(AtlasRb::FileSet).to receive(:update)
    allow(AtlasRb::FileSet).to receive(:set_iiif_service)
    allow(AtlasRb::Work).to receive(:file_sets).and_return([])
    allow(MasterJp2).to receive(:call).and_return('https://iiif.test/iiif/3/123.jp2')
    allow(IiifAssetsJob).to receive(:perform_later)
  end

  describe 'happy path' do
    it 'creates the ordered FileSet with the row idempotency key and attaches the staged page' do
      described_class.new.perform(ingest.id)

      expect(AtlasRb::FileSet).to have_received(:create)
        .with('w-1', 'image', position: 2, idempotency_key: 'idem-2')
      expect(AtlasRb::FileSet).to have_received(:update).with('fs-2', staged_path)
      expect(FileUtils).to have_received(:mv).with(extracted_path, staged_path)
    end

    it 'records both progress stamps and completes the row' do
      described_class.new.perform(ingest.id)

      ingest.reload
      expect(ingest.file_set_pid).to eq('fs-2')
      expect(ingest.blob_attached_at).to be_present
      expect(ingest).to be_completed
    end

    it 'makes no Work.file_sets read on a fresh execution' do
      described_class.new.perform(ingest.id)
      expect(AtlasRb::Work).not_to have_received(:file_sets)
    end

    it 'mints the page JP2 and persists its IIIF service pointer' do
      described_class.new.perform(ingest.id)

      expect(MasterJp2).to have_received(:call).with(path: staged_path)
      expect(AtlasRb::FileSet).to have_received(:set_iiif_service)
        .with('fs-2', 'https://iiif.test/iiif/3/123.jp2')
    end

    it 'completes the page even when the bytes are unreadable for deep zoom' do
      allow(MasterJp2).to receive(:call).and_raise(Vips::Error.new('bad bytes'))
      described_class.new.perform(ingest.id)

      expect(AtlasRb::FileSet).not_to have_received(:set_iiif_service)
      expect(ingest.reload).to be_completed
    end

    it 'never enqueues ContentCreationJob (Work.complete belongs to the barrier)' do
      allow(ContentCreationJob).to receive(:perform_later)
      described_class.new.perform(ingest.id)
      expect(ContentCreationJob).not_to have_received(:perform_later)
    end
  end

  describe 'Work-level thumbnail seeding' do
    it 'fires IiifAssetsJob from page 1' do
      page_one = MultipageIngest.create!(load_report: load_report, source_filename: 'page1.tif',
                                         sequence: 1, work_pid: 'w-1', idempotency_key: 'idem-1')
      one_extracted = File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted', 'page1.tif')
      one_staged = File.join(uploads_root, 'w-1', 'page1.tif')
      allow(File).to receive(:exist?).with(one_staged).and_return(false)
      allow(File).to receive(:exist?).with(one_extracted).and_return(true)

      described_class.new.perform(page_one.id)
      expect(IiifAssetsJob).to have_received(:perform_later).with('w-1', one_staged)
    end

    it 'does not fire IiifAssetsJob from later pages' do
      described_class.new.perform(ingest.id)
      expect(IiifAssetsJob).not_to have_received(:perform_later)
    end
  end

  describe 'retry matrix' do
    it 'skips FileSet.create when file_set_pid is already recorded' do
      ingest.update!(file_set_pid: 'fs-2')
      described_class.new.perform(ingest.id)

      expect(AtlasRb::FileSet).not_to have_received(:create)
      expect(AtlasRb::FileSet).to have_received(:update).with('fs-2', staged_path)
    end

    it 'skips both Atlas writes when both stamps are present' do
      ingest.update!(file_set_pid: 'fs-2', blob_attached_at: 1.minute.ago)
      described_class.new.perform(ingest.id)

      expect(AtlasRb::FileSet).not_to have_received(:create)
      expect(AtlasRb::FileSet).not_to have_received(:update)
      expect(ingest.reload).to be_completed
    end

    it 'skips the JP2 re-mint on resume when the page already carries a service pointer' do
      ingest.update!(file_set_pid: 'fs-2', blob_attached_at: 1.minute.ago)
      allow(AtlasRb::Work).to receive(:file_sets).with('w-1').and_return(
        [{ 'noid' => 'fs-2', 'position' => 2,
           'assets' => [{ 'noid' => 'b-1' }, { 'uri' => 'https://iiif.test/iiif/3/old.jp2' }] }]
      )

      described_class.new.perform(ingest.id)

      expect(MasterJp2).not_to have_received(:call)
      expect(AtlasRb::FileSet).not_to have_received(:set_iiif_service)
    end

    it 're-mints and re-PATCHes on resume when no service pointer landed (Atlas upserts)' do
      ingest.update!(file_set_pid: 'fs-2', blob_attached_at: 1.minute.ago)
      allow(AtlasRb::Work).to receive(:file_sets).with('w-1').and_return(
        [{ 'noid' => 'fs-2', 'position' => 2, 'assets' => [{ 'noid' => 'b-1' }] }]
      )

      described_class.new.perform(ingest.id)

      expect(AtlasRb::FileSet).to have_received(:set_iiif_service)
        .with('fs-2', 'https://iiif.test/iiif/3/123.jp2')
    end

    context 'when resumed past create with no attach stamp' do
      before { ingest.update!(file_set_pid: 'fs-2') }

      it 'consults Atlas and skips the PATCH when the page already holds assets (lost response)' do
        allow(AtlasRb::Work).to receive(:file_sets).with('w-1').and_return(
          [{ 'noid' => 'fs-2', 'position' => 2, 'assets' => [{ 'noid' => 'b-1' }] }]
        )

        described_class.new.perform(ingest.id)

        expect(AtlasRb::FileSet).not_to have_received(:update)
        expect(ingest.reload.blob_attached_at).to be_present
        expect(ingest).to be_completed
      end

      it 'PATCHes once when Atlas shows the page still empty' do
        allow(AtlasRb::Work).to receive(:file_sets).with('w-1').and_return(
          [{ 'noid' => 'fs-2', 'position' => 2, 'assets' => [] }]
        )

        described_class.new.perform(ingest.id)

        expect(AtlasRb::FileSet).to have_received(:update).with('fs-2', staged_path).once
      end
    end

    it 'reuses an already-staged page when the extracted source was consumed by a prior attempt' do
      allow(File).to receive(:exist?).with(staged_path).and_return(true)
      allow(File).to receive(:exist?).with(extracted_path).and_return(false)

      described_class.new.perform(ingest.id)

      expect(FileUtils).not_to have_received(:mv)
      expect(AtlasRb::FileSet).to have_received(:update).with('fs-2', staged_path)
    end
  end

  describe 'permanent failures and guards' do
    it 'fails the row when the page file is nowhere on disk' do
      allow(File).to receive(:exist?).with(extracted_path).and_return(false)

      described_class.new.perform(ingest.id)

      expect(ingest.reload).to be_failed
      expect(ingest.error_message).to include("Page file 'page2.tif' was not found")
      expect(AtlasRb::FileSet).not_to have_received(:create)
    end

    it 'does nothing when the row is already terminal' do
      ingest.update!(status: :completed)
      described_class.new.perform(ingest.id)
      expect(AtlasRb::FileSet).not_to have_received(:create)
    end

    it 'does nothing when the report already failed structurally' do
      load_report.update!(status: :failed)
      described_class.new.perform(ingest.id)

      expect(AtlasRb::FileSet).not_to have_received(:create)
      expect(ingest.reload).to be_pending
    end

    it 'finalizes the parent report after the row settles' do
      expect_any_instance_of(LoadReport).to receive(:maybe_finalize!)
      described_class.new.perform(ingest.id)
    end
  end

  describe 'retry policy' do
    it 'declares retry_on StandardError so transient failures auto-retry' do
      handlers = described_class.rescue_handlers.map(&:first)
      expect(handlers).to include('StandardError')
    end
  end
end
