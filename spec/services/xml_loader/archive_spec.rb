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

  describe '#basenames' do
    it 'lists every relevant entry basename without extracting' do
      names = described_class.new(fixture).basenames
      expect(names).to be_a(Set)
      expect(names).to include('manifest.xlsx', 'sample_mods_with_handle_0.xml')
    end
  end

  describe '#zip?' do
    it 'is true for .zip and false otherwise' do
      expect(described_class.new('/tmp/x.zip')).to be_zip
      expect(described_class.new('/tmp/x.tar')).not_to be_zip
    end
  end

  # Tar takes a separate code path for all three readers, because a tar has no
  # central directory: every operation walks the headers instead of seeking. The
  # nested fixture carries the macOS cruft a real upload does, so it also covers
  # the entries the walk has to drop.
  describe 'a tar archive' do
    let(:flat) { Rails.root.join('spec/fixtures/files/jpgs.tar').to_s }
    let(:nested) { Rails.root.join('spec/fixtures/files/jpgs_nested.tar').to_s }

    describe '#read' do
      it 'returns the bytes of a named entry (case-insensitively)' do
        bytes = described_class.new(flat).read('NEU_64574.JPG')

        expect(bytes).to be_a(String)
        expect(bytes.bytesize).to be > 0
      end

      it 'finds an entry inside a directory, by basename alone' do
        expect(described_class.new(nested).read('neu_64574.jpg')).to be_a(String)
      end

      it 'returns nil for an entry that is not present' do
        expect(described_class.new(flat).read('does-not-exist.xml')).to be_nil
      end
    end

    describe '#basenames' do
      it 'lists every relevant entry basename without extracting' do
        names = described_class.new(flat).basenames

        expect(names).to be_a(Set)
        expect(names).to contain_exactly('marcom_mod_name.jpg', 'neu_247433.jpg', 'neu_64574.jpg')
      end

      it 'drops directories and macOS resource forks' do
        names = described_class.new(nested).basenames

        expect(names).to include('neu_64574.jpg')
        expect(names.grep(/\A\._/)).to be_empty
        expect(names).not_to include('jpgs')
      end
    end

    describe '#extract_all' do
      let(:dest) { Dir.mktmpdir('archive-tar-spec') }

      after { FileUtils.rm_rf(dest) }

      it 'writes every relevant entry to disk and yields each basename' do
        yielded = []
        described_class.new(flat).extract_all(dest) { |name| yielded << name }

        expect(yielded).to contain_exactly('marcom_mod_name.jpg', 'neu_247433.jpg', 'neu_64574.jpg')
        expect(File).to exist(File.join(dest, 'neu_64574.jpg'))
        expect(File.size(File.join(dest, 'neu_64574.jpg'))).to be > 0
      end

      it 'flattens a nested entry to its basename and skips the resource forks' do
        described_class.new(nested).extract_all(dest)

        expect(File).to exist(File.join(dest, 'neu_64574.jpg'))
        expect(Dir.children(dest).grep(/\A\._/)).to be_empty
      end

      it 'takes an entry with no block' do
        expect { described_class.new(flat).extract_all(dest) }.not_to raise_error
        expect(Dir.children(dest)).to include('neu_64574.jpg')
      end
    end
  end
end
