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

    # An entry named to climb out of the destination is written by its
    # basename, inside it — nothing reaches the parent or a sibling directory.
    it 'keeps a path-traversal entry inside the destination' do
      zip_path = File.join(Dir.mktmpdir('archive-spec-zip'), 'hostile.zip')
      Zip::OutputStream.open(zip_path) do |out|
        out.put_next_entry('../escape.txt')
        out.write('climbed')
        out.put_next_entry('pages/page1.jpg')
        out.write('jpeg')
      end

      described_class.new(zip_path).extract_all(dest)

      expect(File.read(File.join(dest, 'escape.txt'))).to eq('climbed')
      expect(File).to exist(File.join(dest, 'page1.jpg'))
      expect(File).not_to exist(File.join(File.dirname(dest), 'escape.txt'))
    ensure
      FileUtils.rm_rf(File.dirname(zip_path)) if zip_path
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

  describe '#extract_one and #size_of' do
    let(:create_zip) { Rails.root.join('spec/fixtures/files/xml_loader_create_sample.zip').to_s }
    let(:dest_dir) { Dir.mktmpdir('archive-one') }

    after { FileUtils.rm_rf(dest_dir) }

    # A tar with one content file, built here so both archive formats are covered.
    def build_tar(name, bytes)
      path = File.join(dest_dir, 'sample.tar')
      File.open(path, 'wb') do |io|
        Gem::Package::TarWriter.new(io) { |tar| tar.add_file_simple(name, 0o644, bytes.bytesize) { |f| f.write(bytes) } }
      end
      path
    end

    it 'streams one zip entry to disk, matching its name case-insensitively' do
      dest = File.join(dest_dir, 'out.jpg')
      expect(described_class.new(create_zip).extract_one('FLOWER.JPG', dest)).to eq(dest)
      expect(File.size(dest)).to eq(104_297)
    end

    it 'reads a zip entry\'s size from the directory, without extracting it' do
      expect(described_class.new(create_zip).size_of('flower.jpg')).to eq(104_297)
      expect(Dir.children(dest_dir)).to be_empty
    end

    it 'streams one tar entry to disk and reads its size from the header' do
      tar = described_class.new(build_tar('images/photo.tif', 'x' * 2048))
      dest = File.join(dest_dir, 'photo.tif')

      expect(tar.size_of('photo.tif')).to eq(2048)
      expect(tar.extract_one('photo.tif', dest)).to eq(dest)
      expect(File.size(dest)).to eq(2048)
    end

    it 'is nil for an entry that is not present, and writes nothing' do
      dest = File.join(dest_dir, 'missing.jpg')
      expect(described_class.new(create_zip).extract_one('missing.jpg', dest)).to be_nil
      expect(described_class.new(create_zip).size_of('missing.jpg')).to be_nil
      expect(File).not_to exist(dest)
    end
  end
end
