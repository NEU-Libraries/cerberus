# frozen_string_literal: true

require 'rails_helper'

RSpec.describe XmlLoader::Archive do
  let(:fixture) { Rails.root.join('spec/fixtures/files/metadata_existing_files.zip').to_s }

  describe '#read' do
    subject(:archive) { described_class.new(fixture) }

    it 'returns the bytes of a named entry (case-insensitively)' do
      bytes = archive.read('MANIFEST.XLSX')
      expect(bytes).to be_a(String)
      expect(bytes.bytesize).to be > 0
    end

    it 'returns nil for an entry that is not present' do
      expect(archive.read('does-not-exist.xml')).to be_nil
    end
  end

  describe '#extract_all' do
    let(:dest) { Dir.mktmpdir('archive-spec') }

    after { FileUtils.rm_rf(dest) }

    it 'writes every relevant entry to disk and yields each basename' do
      yielded = []
      described_class.new(fixture).extract_all(dest) { |name| yielded << name }

      expect(yielded).to include('manifest.xlsx', 'sample_mods_with_handle_0.xml')
      expect(File).to exist(File.join(dest, 'manifest.xlsx'))
      expect(File).to exist(File.join(dest, 'sample_mods_with_handle_4.xml'))
    end
  end

  describe '#zip?' do
    it 'is true for .zip and false otherwise' do
      expect(described_class.new('/tmp/x.zip')).to be_zip
      expect(described_class.new('/tmp/x.tar')).not_to be_zip
    end
  end
end
