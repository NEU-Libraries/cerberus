# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageUnzipJob, type: :job do
  let(:loader) { create(:loader, :multipage) }
  let(:load_report) do
    LoadReport.create!(loader: loader, parent_collection_id: 'col-abc',
                       source_filename: 'postcard.zip', status: :pending)
  end

  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:extracted_dir) { File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted') }
  let(:manifest_path) { File.join(extracted_dir, 'manifest.xlsx') }
  let(:mods_path) { File.join(extracted_dir, 'w.mods.xml') }

  let(:basenames) { %w[manifest.xlsx w.mods.xml p1.tif p2.tif] }
  let(:archive) { instance_double(XmlLoader::Archive) }

  def row(file_name:, sequence:, xml_path: nil, last_item: false)
    MultipageLoader::Manifest::Row.new(file_name: file_name, xml_path: xml_path,
                                       sequence_raw: sequence, last_item_raw: last_item)
  end

  let(:good_rows) do
    [
      row(file_name: 'w.mods.xml', xml_path: 'w.mods.xml', sequence: 0),
      row(file_name: 'p1.tif', sequence: 1),
      row(file_name: 'p2.tif', sequence: 2, last_item: true)
    ]
  end

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(manifest_path).and_return(true)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(mods_path).and_return('<mods:mods/>')
    allow(XmlLoader::Archive).to receive(:new).and_return(archive)
    allow(archive).to receive(:extract_all) { |_, &blk| basenames.each(&blk) }
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Work).to receive(:create).and_return(double(id: 'w-new'))
  end

  def stub_manifest(rows)
    allow(MultipageLoader::Manifest).to receive(:new).with(manifest_path)
                                                     .and_return(instance_double(MultipageLoader::Manifest, rows: rows))
  end

  describe 'happy path: one Work, rows-then-enqueue fan-out' do
    before { stub_manifest(good_rows) }

    it 'mints exactly one Work from the MODS with a fresh idempotency key' do
      described_class.new.perform(load_report.id)
      expect(AtlasRb::Work).to have_received(:create)
        .with('col-abc', mods_path, idempotency_key: kind_of(String)).once
    end

    it 'creates one ingest row per PAGE (not the MODS row), stamped with the shared work_pid' do
      expect { described_class.new.perform(load_report.id) }
        .to change { load_report.multipage_ingests.count }.by(2)

      rows = load_report.multipage_ingests.order(:sequence)
      expect(rows.map(&:sequence)).to eq([1, 2])
      expect(rows.map(&:source_filename)).to eq(%w[p1.tif p2.tif])
      expect(rows.map(&:work_pid)).to all(eq('w-new'))
      expect(rows.map(&:idempotency_key).uniq.length).to eq(2)
    end

    it 'enqueues one MultipageIngestJob per page' do
      expect { described_class.new.perform(load_report.id) }
        .to have_enqueued_job(MultipageIngestJob).twice
    end

    it 'starts the LoadReport' do
      described_class.new.perform(load_report.id)
      expect(load_report.reload).to be_processing
    end
  end

  describe 'contract enforcement before any Atlas write' do
    it 'rejects the bad-sequence shape with zero Atlas calls (the headline guarantee)' do
      stub_manifest(
        [
          row(file_name: 'w.mods.xml', xml_path: 'w.mods.xml', sequence: 0),
          row(file_name: 'p1.tif', sequence: 3),
          row(file_name: 'p2.tif', sequence: 1, last_item: true)
        ]
      )

      described_class.new.perform(load_report.id)

      expect(AtlasRb::Work).not_to have_received(:create)
      expect(load_report.reload).to be_failed
      failure = load_report.multipage_ingests.failed.sole
      expect(failure.source_filename).to eq('manifest.xlsx')
      expect(failure.error_message).to include('must run 1 through 2 with no gaps — got 1, 3')
        .and include('Last Item is flagged on Sequence 1')
    end

    it 'rejects invalid MODS before minting' do
      stub_manifest(good_rows)
      allow(XmlValidator).to receive(:call).and_return(['not schema-valid'])

      described_class.new.perform(load_report.id)

      expect(AtlasRb::Work).not_to have_received(:create)
      expect(load_report.multipage_ingests.failed.sole.error_message).to include('Invalid MODS: not schema-valid')
    end
  end

  describe 'structural failures surface as one failed ingest' do
    it 'fails the report when no manifest is present' do
      allow(File).to receive(:exist?).with(manifest_path).and_return(false)

      described_class.new.perform(load_report.id)

      failure = load_report.multipage_ingests.failed.sole
      expect(failure.error_message).to match(/No manifest/i)
      expect(load_report.reload).to be_failed
    end

    it 'fails the report when the manifest header is unrecognized' do
      allow(MultipageLoader::Manifest).to receive(:new)
        .and_raise(MultipageLoader::Manifest::HeaderError, 'The manifest has no recognizable header row.')

      described_class.new.perform(load_report.id)

      expect(load_report.multipage_ingests.failed.sole.error_message).to match(/header row/i)
      expect(load_report.reload).to be_failed
    end

    it 'fails the report when the manifest has no data rows' do
      stub_manifest([])

      described_class.new.perform(load_report.id)

      expect(load_report.multipage_ingests.failed.sole.error_message).to match(/no data rows/i)
    end

    it 'fails the report when the Work mint is refused by Atlas' do
      stub_manifest(good_rows)
      allow(AtlasRb::Work).to receive(:create).and_raise(Faraday::ConnectionFailed.new('down'))

      described_class.new.perform(load_report.id)

      expect(load_report.multipage_ingests.failed.sole.error_message).to include('Could not create the Work in Atlas')
      expect(load_report.multipage_ingests.count).to eq(1) # no page rows
      expect(load_report.reload).to be_failed
    end
  end

  describe 'guards' do
    it 'does nothing unless the report is pending' do
      load_report.update!(status: :previewing)
      described_class.new.perform(load_report.id)

      expect(AtlasRb::Work).not_to have_received(:create)
      expect(load_report.reload).to be_previewing
    end

    it 'fails the load on an unexpected error without raising' do
      allow(archive).to receive(:extract_all).and_raise(Zip::Error, 'corrupt archive')

      expect { described_class.new.perform(load_report.id) }.not_to raise_error
      expect(load_report.reload).to be_failed
    end
  end
end
