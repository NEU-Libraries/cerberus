# frozen_string_literal: true

require 'rails_helper'

RSpec.describe XmlIngestJob, type: :job do
  let(:load_report) do
    LoadReport.create!(parent_collection_id: 'col-abc', source_filename: 'load.zip')
  end
  let(:ingest) do
    XmlIngest.create!(load_report: load_report, source_filename: 'rec.xml', idempotency_key: 'idem-1')
  end

  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:extracted_dir) { File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted') }
  let(:mods_path) { File.join(extracted_dir, 'rec.xml') }
  let(:content_path) { File.join(extracted_dir, 'pic.tif') }

  let(:update_row) { { 'identifier' => 'noid-9', 'xml_path' => 'rec.xml' } }
  let(:create_row) { { 'file_name' => 'pic.tif', 'xml_path' => 'rec.xml' } }

  before do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(mods_path).and_return(true)
    allow(File).to receive(:exist?).with(content_path).and_return(true)
    allow(File).to receive(:read).with(mods_path).and_return('<mods:mods/>')
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Work).to receive(:update)
    allow(AtlasRb::Work).to receive(:create).and_return(double(id: 'w-new'))
    allow(AtlasRb::Work).to receive(:metadata)
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:mv)
    allow(Marcel::MimeType).to receive(:for).and_return('image/tiff')
    allow(ContentCreationJob).to receive(:perform_later)
    allow(IiifAssetsJob).to receive(:perform_later)
  end

  describe 'update mode (row carries an identifier)' do
    it 'replaces the existing Work MODS via Work.update by NOID' do
      described_class.new.perform(ingest.id, update_row)
      expect(AtlasRb::Work).to have_received(:update).with('noid-9', kind_of(String))
    end

    it 'records the NOID as work_pid and completes' do
      described_class.new.perform(ingest.id, update_row)
      expect(ingest.reload.work_pid).to eq('noid-9')
      expect(ingest).to be_completed
    end

    it 'does not create a new Work' do
      expect(AtlasRb::Work).not_to receive(:create)
      described_class.new.perform(ingest.id, update_row)
    end

    it 'finalizes the parent LoadReport' do
      expect_any_instance_of(LoadReport).to receive(:maybe_finalize!)
      described_class.new.perform(ingest.id, update_row)
    end
  end

  describe 'create mode (row carries a file name, no identifier)' do
    it 'mints a Work seeded with the MODS, using parent collection + idempotency key' do
      described_class.new.perform(ingest.id, create_row)
      expect(AtlasRb::Work).to have_received(:create).with('col-abc', kind_of(String), idempotency_key: 'idem-1')
      expect(ingest.reload.work_pid).to eq('w-new')
    end

    it 'stages the content file into the per-Work uploads dir' do
      described_class.new.perform(ingest.id, create_row)
      expect(FileUtils).to have_received(:mv).with(content_path, File.join(uploads_root, 'w-new', 'pic.tif'))
    end

    it 'enqueues ContentCreationJob and (for images) IiifAssetsJob' do
      described_class.new.perform(ingest.id, create_row)
      expect(ContentCreationJob).to have_received(:perform_later)
        .with('w-new', File.join(uploads_root, 'w-new', 'pic.tif'), 'pic.tif', 'idem-1')
      expect(IiifAssetsJob).to have_received(:perform_later).with('w-new', File.join(uploads_root, 'w-new', 'pic.tif'))
    end

    it 'skips IiifAssetsJob for non-image content' do
      allow(Marcel::MimeType).to receive(:for).and_return('application/pdf')
      described_class.new.perform(ingest.id, create_row)
      expect(IiifAssetsJob).not_to have_received(:perform_later)
      expect(ContentCreationJob).to have_received(:perform_later)
    end

    it 'fails the row when the named content file is missing' do
      allow(File).to receive(:exist?).with(content_path).and_return(false)
      expect(AtlasRb::Work).not_to receive(:create)
      described_class.new.perform(ingest.id, create_row)
      expect(ingest.reload).to be_failed
      expect(ingest.error_message).to match(/Content file 'pic.tif' was not found/)
    end
  end

  describe 'embargo' do
    it 'sets the embargo release date via Work.metadata when the row opts in' do
      row = update_row.merge('embargoed' => 'true', 'embargo_date' => '2030-01-01')
      described_class.new.perform(ingest.id, row)
      expect(AtlasRb::Work).to have_received(:metadata).with('noid-9', { permissions: { embargo: '2030-01-01' } })
      expect(ingest.reload).to be_completed
    end

    it 'fails the row when embargoed without a valid YYYY-MM-DD date' do
      row = update_row.merge('embargoed' => 'true', 'embargo_date' => 'soon')
      described_class.new.perform(ingest.id, row)
      expect(AtlasRb::Work).not_to have_received(:metadata)
      expect(ingest.reload).to be_failed
      expect(ingest.error_message).to match(/Embargo Date/)
    end
  end

  describe 'per-row validation failures' do
    it 'fails when the row has neither identifier nor file name' do
      described_class.new.perform(ingest.id, { 'xml_path' => 'rec.xml' })
      expect(ingest.reload).to be_failed
      expect(ingest.error_message).to match(/neither an identifier.*nor a File Name/)
    end

    it 'fails when the row has no MODS XML File Path' do
      described_class.new.perform(ingest.id, { 'identifier' => 'noid-9' })
      expect(ingest.reload.error_message).to match(/no MODS XML File Path/)
    end

    it 'fails when the referenced MODS file is absent from the archive' do
      allow(File).to receive(:exist?).with(mods_path).and_return(false)
      described_class.new.perform(ingest.id, update_row)
      expect(ingest.reload.error_message).to match(/was not found in the archive/)
      expect(AtlasRb::Work).not_to have_received(:update)
    end

    it 'fails when the MODS is invalid' do
      allow(XmlValidator).to receive(:call).and_return(['Document must declare xmlns:mods'])
      described_class.new.perform(ingest.id, update_row)
      expect(ingest.reload).to be_failed
      expect(ingest.error_message).to match(/Invalid MODS.*xmlns:mods/)
      expect(AtlasRb::Work).not_to have_received(:update)
    end
  end

  describe 'idempotency' do
    %i[completed completed_with_warnings failed].each do |state|
      it "no-ops when already #{state}" do
        ingest.update!(status: state)
        expect(AtlasRb::Work).not_to receive(:update)
        expect(AtlasRb::Work).not_to receive(:create)
        described_class.new.perform(ingest.id, update_row)
      end
    end

    it 'skips Work.create on a create-mode retry where work_pid is already set' do
      ingest.update!(work_pid: 'w-existing', status: :processing)
      expect(AtlasRb::Work).not_to receive(:create)
      described_class.new.perform(ingest.id, create_row)
    end
  end

  describe 'retry policy' do
    it 'declares retry_on StandardError so transient failures auto-retry' do
      handler = described_class.rescue_handlers.find { |h| h[0] == 'StandardError' }
      expect(handler).not_to be_nil
    end
  end
end
