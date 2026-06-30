# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultipageUnzipJob, type: :job do
  let(:loader) { create(:loader, :multipage) }
  let(:load_report) do
    LoadReport.create!(loader: loader, parent_collection_id: 'col-abc',
                       source_filename: 'postcards.zip', status: :pending)
  end

  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:extracted_dir) { File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted') }
  let(:manifest_path) { File.join(extracted_dir, 'manifest.xlsx') }

  let(:basenames) { %w[manifest.xlsx a.mods.xml a1.tif a2.tif b.mods.xml b1.tif b2.tif] }
  let(:archive) { instance_double(XmlLoader::Archive) }

  def row(file_name:, sequence:, xml_path: nil, last_item: false)
    MultipageLoader::Manifest::Row.new(file_name: file_name, xml_path: xml_path,
                                       sequence_raw: sequence, last_item_raw: last_item)
  end

  # One valid item: a.mods.xml + two ordered pages.
  let(:one_item_rows) do
    [
      row(file_name: 'a.mods.xml', xml_path: 'a.mods.xml', sequence: 0),
      row(file_name: 'a1.tif', sequence: 1),
      row(file_name: 'a2.tif', sequence: 2, last_item: true)
    ]
  end

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(manifest_path).and_return(true)
    allow(XmlLoader::Archive).to receive(:new).and_return(archive)
    allow(archive).to receive(:extract_all) { |_, &blk| basenames.each(&blk) }
    # The unzip job is local-only — it must never call Atlas or the validator.
    allow(AtlasRb::Work).to receive(:create)
    allow(XmlValidator).to receive(:call)
  end

  def stub_manifest(rows)
    allow(MultipageLoader::Manifest).to receive(:new).with(manifest_path)
                                                     .and_return(instance_double(MultipageLoader::Manifest, rows: rows))
  end

  describe 'a single valid item' do
    before { stub_manifest(one_item_rows) }

    it 'makes no Atlas or validator calls (the headline guarantee)' do
      described_class.new.perform(load_report.id)
      expect(AtlasRb::Work).not_to have_received(:create)
      expect(XmlValidator).not_to have_received(:call)
    end

    it 'creates one pending page row per page, grouped by item_index, work_pid still nil' do
      expect { described_class.new.perform(load_report.id) }
        .to change { load_report.multipage_ingests.count }.by(2)

      rows = load_report.multipage_ingests.order(:sequence)
      expect(rows.map(&:sequence)).to eq([1, 2])
      expect(rows.map(&:source_filename)).to eq(%w[a1.tif a2.tif])
      expect(rows.map(&:item_index)).to all(eq(0))
      expect(rows.map(&:work_pid)).to all(be_nil)
      expect(rows.map(&:idempotency_key).uniq.length).to eq(2)
      expect(rows).to all(be_pending)
    end

    it 'fans out one MultipageItemJob carrying the MODS basename and a fresh mint key' do
      expect { described_class.new.perform(load_report.id) }
        .to have_enqueued_job(MultipageItemJob)
        .with(load_report.id, 0, 'a.mods.xml', work_idempotency_key: kind_of(String))
        .exactly(:once)
    end

    it 'enqueues no page job itself (the item job owns page fan-out)' do
      expect { described_class.new.perform(load_report.id) }.not_to have_enqueued_job(MultipageIngestJob)
    end

    it 'starts the report and leaves it processing while pages are pending' do
      described_class.new.perform(load_report.id)
      expect(load_report.reload).to be_processing
    end
  end

  describe 'multiple items' do
    let(:multi_rows) do
      [
        row(file_name: 'a.mods.xml', xml_path: 'a.mods.xml', sequence: 0),
        row(file_name: 'a1.tif', sequence: 1, last_item: true),
        row(file_name: 'b.mods.xml', xml_path: 'b.mods.xml', sequence: 0),
        row(file_name: 'b1.tif', sequence: 1),
        row(file_name: 'b2.tif', sequence: 2, last_item: true)
      ]
    end

    before { stub_manifest(multi_rows) }

    it 'fans out one item job per item with its own index and MODS' do
      expect { described_class.new.perform(load_report.id) }
        .to have_enqueued_job(MultipageItemJob).with(load_report.id, 0, 'a.mods.xml', work_idempotency_key: kind_of(String))
        .and have_enqueued_job(MultipageItemJob).with(load_report.id, 1, 'b.mods.xml', work_idempotency_key: kind_of(String))
    end

    it 'creates each item\'s page rows under its own item_index, sequence reset per item' do
      described_class.new.perform(load_report.id)
      grouped = load_report.multipage_ingests.order(:item_index, :sequence)
                           .group_by(&:item_index).transform_values { |rows| rows.map(&:sequence) }
      expect(grouped).to eq(0 => [1], 1 => [1, 2])
    end
  end

  describe 'skip bad, ingest valid' do
    let(:mixed_rows) do
      [
        # valid item 0
        row(file_name: 'a.mods.xml', xml_path: 'a.mods.xml', sequence: 0),
        row(file_name: 'a1.tif', sequence: 1, last_item: true),
        # invalid item 1 — page sequence gap
        row(file_name: 'b.mods.xml', xml_path: 'b.mods.xml', sequence: 0),
        row(file_name: 'b1.tif', sequence: 1),
        row(file_name: 'b3.tif', sequence: 3, last_item: true)
      ]
    end

    before { stub_manifest(mixed_rows) }

    it 'records a failed summary row for the bad item and enqueues a job only for the good one' do
      expect { described_class.new.perform(load_report.id) }
        .to have_enqueued_job(MultipageItemJob).exactly(:once)

      failed = load_report.multipage_ingests.failed.sole
      expect(failed.item_index).to eq(1)
      expect(failed.source_filename).to eq('b.mods.xml')
      expect(failed.error_message).to include('must run 1 through 2 with no gaps — got 1, 3')
      expect(failed.sequence).to be_nil
    end

    it 'leaves the report processing (the good item\'s pages are still pending)' do
      described_class.new.perform(load_report.id)
      expect(load_report.reload).to be_processing
    end
  end

  describe 'all items invalid' do
    before do
      stub_manifest(
        [row(file_name: 'a1.tif', sequence: 1, last_item: true)] # no Sequence 0 MODS row
      )
    end

    it 'fails the report with no item job enqueued' do
      expect { described_class.new.perform(load_report.id) }.not_to have_enqueued_job(MultipageItemJob)
      expect(load_report.reload).to be_failed
      expect(load_report.multipage_ingests.failed.sole.error_message).to include('exactly one Sequence 0 row')
    end
  end

  describe 'structural failures surface as one failed manifest row' do
    it 'fails when no manifest is present' do
      allow(File).to receive(:exist?).with(manifest_path).and_return(false)
      described_class.new.perform(load_report.id)

      failure = load_report.multipage_ingests.failed.sole
      expect(failure.source_filename).to eq('manifest.xlsx')
      expect(failure.error_message).to match(/No manifest/i)
      expect(load_report.reload).to be_failed
    end

    it 'fails when the manifest header is unrecognized' do
      allow(MultipageLoader::Manifest).to receive(:new)
        .and_raise(MultipageLoader::Manifest::HeaderError, 'The manifest has no recognizable header row.')
      described_class.new.perform(load_report.id)

      expect(load_report.multipage_ingests.failed.sole.error_message).to match(/header row/i)
      expect(load_report.reload).to be_failed
    end

    it 'fails when the manifest has no data rows' do
      stub_manifest([])
      described_class.new.perform(load_report.id)
      expect(load_report.multipage_ingests.failed.sole.error_message).to match(/no data rows/i)
    end
  end

  describe 'guards' do
    it 'does nothing unless the report is pending' do
      load_report.update!(status: :previewing)
      expect { described_class.new.perform(load_report.id) }.not_to have_enqueued_job(MultipageItemJob)
      expect(load_report.reload).to be_previewing
    end

    it 'fails the load on an unexpected error without raising' do
      allow(archive).to receive(:extract_all).and_raise(Zip::Error, 'corrupt archive')
      expect { described_class.new.perform(load_report.id) }.not_to raise_error
      expect(load_report.reload).to be_failed
    end
  end
end
