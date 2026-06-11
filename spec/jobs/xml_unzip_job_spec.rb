# frozen_string_literal: true

require 'rails_helper'

RSpec.describe XmlUnzipJob, type: :job do
  let(:loader) { create(:loader, :xml) }
  let(:load_report) do
    LoadReport.create!(loader: loader, parent_collection_id: 'col-abc',
                       source_filename: 'load.zip', status: :pending)
  end

  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:manifest_path) do
    File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted', 'manifest.xlsx')
  end

  let(:archive) { instance_double(XmlLoader::Archive, extract_all: nil) }

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:exist?).and_call_original
    allow(XmlLoader::Archive).to receive(:new).and_return(archive)
  end

  describe 'manifest-driven fan-out' do
    let(:rows) do
      [
        XmlLoader::Manifest::Row.new(identifier: 'noid-1', xml_path: 'a.xml'),
        XmlLoader::Manifest::Row.new(file_name: 'b.tif', xml_path: 'b.xml')
      ]
    end

    before do
      allow(File).to receive(:exist?).with(manifest_path).and_return(true)
      allow(XmlLoader::Manifest).to receive(:new).with(manifest_path)
                                                 .and_return(instance_double(XmlLoader::Manifest, rows: rows))
    end

    it 'starts the LoadReport' do
      described_class.new.perform(load_report.id)
      expect(load_report.reload).to be_processing
    end

    it 'creates one XmlIngest per manifest row' do
      expect { described_class.new.perform(load_report.id) }
        .to change { load_report.xml_ingests.count }.by(2)
    end

    it 'names each ingest by identifier (update) or file name (create)' do
      described_class.new.perform(load_report.id)
      names = load_report.xml_ingests.pluck(:source_filename)
      expect(names).to contain_exactly('noid-1', 'b.tif')
    end

    it 'enqueues one XmlIngestJob per row carrying the row hash' do
      expect { described_class.new.perform(load_report.id) }
        .to have_enqueued_job(XmlIngestJob).twice
    end

    it 'mints a unique idempotency_key per ingest' do
      described_class.new.perform(load_report.id)
      keys = load_report.xml_ingests.pluck(:idempotency_key)
      expect(keys.uniq.length).to eq(2)
      expect(keys).to all(be_present)
    end
  end

  describe 'structural failures surface as one failed ingest' do
    it 'fails the report when no manifest is present' do
      allow(File).to receive(:exist?).with(manifest_path).and_return(false)

      described_class.new.perform(load_report.id)

      expect(load_report.xml_ingests.failed.count).to eq(1)
      expect(load_report.xml_ingests.first.error_message).to match(/No manifest/i)
      expect(load_report.reload).to be_failed
    end

    it 'fails the report when the manifest header is unrecognized' do
      allow(File).to receive(:exist?).with(manifest_path).and_return(true)
      allow(XmlLoader::Manifest).to receive(:new)
        .and_raise(XmlLoader::Manifest::HeaderError, 'no header')

      described_class.new.perform(load_report.id)

      expect(load_report.xml_ingests.failed.count).to eq(1)
      expect(load_report.reload).to be_failed
    end

    it 'fails the report when the manifest has a header but no data rows' do
      allow(File).to receive(:exist?).with(manifest_path).and_return(true)
      allow(XmlLoader::Manifest).to receive(:new)
        .and_return(instance_double(XmlLoader::Manifest, rows: []))

      described_class.new.perform(load_report.id)

      expect(load_report.xml_ingests.failed.first.error_message).to match(/no data rows/i)
      expect(load_report.reload).to be_failed
    end
  end

  describe 'idempotency — non-pending LoadReport' do
    %i[processing completed failed previewing].each do |state|
      it "no-ops when status is #{state}" do
        load_report.update!(status: state)
        expect(XmlLoader::Archive).not_to receive(:new)
        described_class.new.perform(load_report.id)
      end
    end
  end

  describe 'unexpected error' do
    it 'fails the report without raising (so Solid Queue does not retry)' do
      allow(File).to receive(:exist?).with(manifest_path).and_return(true)
      allow(XmlLoader::Manifest).to receive(:new).and_raise(StandardError, 'boom')

      expect { described_class.new.perform(load_report.id) }.not_to raise_error
      expect(load_report.reload).to be_failed
    end
  end
end
