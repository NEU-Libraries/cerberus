# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UnzipJob, type: :job do
  let(:load_report) do
    LoadReport.create!(parent_collection_id: 'col-abc', source_filename: 'jpgs.zip')
  end

  let(:uploads_root) { Rails.application.config.x.cerberus.uploads_root }
  let(:extracted_dir) do
    File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted')
  end
  let(:archive_path) do
    File.join(uploads_root, 'load_reports', load_report.id.to_s, 'jpgs.zip')
  end

  describe 'zip extraction' do
    let(:entries) do
      [
        instance_double(Zip::Entry, name: 'one.jpg'),
        instance_double(Zip::Entry, name: 'two.jpg'),
        instance_double(Zip::Entry, name: 'readme.txt'),       # skipped: not a JPEG
        instance_double(Zip::Entry, name: '__MACOSX/x.jpg'),   # skipped: mac metadata
        instance_double(Zip::Entry, name: 'sub/dir/two.jpg')   # skipped: duplicate basename
      ]
    end
    let(:zip_file) { instance_double(Zip::File) }

    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(Zip::File).to receive(:open).with(archive_path).and_yield(zip_file)
      allow(zip_file).to receive(:each) { |&b| entries.each(&b) }
      allow(File).to receive(:exist?).and_return(false)
      entries.each { |e| allow(e).to receive(:extract) }
    end

    it 'creates one IptcIngest per relevant JPEG entry' do
      expect { described_class.new.perform(load_report.id) }
        .to change(IptcIngest, :count).by(2)
    end

    it 'streams each entry to disk via Zip::Entry#extract (not read)' do
      described_class.new.perform(load_report.id)
      expect(entries[0]).to have_received(:extract).with(File.join(extracted_dir, 'one.jpg'))
      expect(entries[1]).to have_received(:extract).with(File.join(extracted_dir, 'two.jpg'))
    end

    it 'never invokes get_input_stream (streaming-API discipline)' do
      entries.each { |e| expect(e).not_to receive(:get_input_stream) }
      described_class.new.perform(load_report.id)
    end

    it 'skips entries whose basename was already extracted' do
      described_class.new.perform(load_report.id)
      expect(entries[4]).not_to have_received(:extract)
    end

    it 'enqueues one IptcIngestJob per created IptcIngest' do
      expect { described_class.new.perform(load_report.id) }
        .to have_enqueued_job(IptcIngestJob).twice
    end

    it 'transitions LoadReport to :processing on start' do
      described_class.new.perform(load_report.id)
      expect(load_report.reload).to be_processing
    end

    it 'mints a fresh idempotency_key per IptcIngest' do
      described_class.new.perform(load_report.id)
      keys = IptcIngest.where(load_report: load_report).pluck(:idempotency_key)
      expect(keys).to all(be_a(String).and(be_present))
      expect(keys.uniq.length).to eq(keys.length)
    end
  end

  describe 'tar extraction' do
    let(:tar_report) do
      LoadReport.create!(parent_collection_id: 'col-abc', source_filename: 'jpgs.tar')
    end
    let(:tar_archive_path) do
      File.join(uploads_root, 'load_reports', tar_report.id.to_s, 'jpgs.tar')
    end
    let(:tar_entries) do
      [
        double('TarEntry', file?: true, full_name: 'one.jpg'),
        double('TarEntry', file?: true, full_name: 'two.jpg'),
        double('TarEntry', file?: false, full_name: 'a-dir/') # directory entry, skipped
      ]
    end
    let(:tar_reader) { double('TarReader') }
    let(:archive_file) { double('File') }
    let(:out) { double('Out') }

    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:open).with(tar_archive_path, 'rb').and_yield(archive_file)
      allow(File).to receive(:open).with(/extracted/, 'wb').and_yield(out)
      allow(File).to receive(:exist?).and_return(false)
      allow(Gem::Package::TarReader).to receive(:new).with(archive_file).and_yield(tar_reader)
      allow(tar_reader).to receive(:each) { |&b| tar_entries.each(&b) }
      tar_entries.each { |e| allow(IO).to receive(:copy_stream).with(e, out) }
    end

    it 'uses IO.copy_stream (streaming) for each tar entry' do
      described_class.new.perform(tar_report.id)
      expect(IO).to have_received(:copy_stream).with(tar_entries[0], out)
      expect(IO).to have_received(:copy_stream).with(tar_entries[1], out)
    end

    it 'skips non-file entries (directories)' do
      described_class.new.perform(tar_report.id)
      expect(IO).not_to have_received(:copy_stream).with(tar_entries[2], anything)
    end

    it 'creates one IptcIngest per file entry that is a JPEG' do
      expect { described_class.new.perform(tar_report.id) }
        .to change { tar_report.iptc_ingests.count }.by(2)
    end
  end

  describe 'idempotency — non-pending LoadReport' do
    %i[processing completed failed completed_with_warnings].each do |state|
      context "when LoadReport status is #{state}" do
        before { load_report.update!(status: state) }

        it 'no-ops without re-opening the archive' do
          expect(Zip::File).not_to receive(:open)
          described_class.new.perform(load_report.id)
        end
      end
    end
  end

  describe 'malformed archive' do
    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(Zip::File).to receive(:open).and_raise(Zip::Error, 'invalid central directory')
    end

    it 'transitions the LoadReport to :failed' do
      described_class.new.perform(load_report.id)
      expect(load_report.reload).to be_failed
    end

    it 'does not raise to Solid Queue (so the job is not retried)' do
      expect { described_class.new.perform(load_report.id) }.not_to raise_error
    end

    it 'does not create any IptcIngest rows' do
      expect { described_class.new.perform(load_report.id) }.not_to change(IptcIngest, :count)
    end
  end
end
