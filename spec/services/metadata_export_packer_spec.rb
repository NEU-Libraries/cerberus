# frozen_string_literal: true

require 'rails_helper'
require 'zip'
require 'tempfile'

# Unit spec for the export bundle's shape. Streams into a real ZipKit::Streamer
# (over a StringIO) and reads the bytes back, so the assertions are against the
# actual archive a client would download. AtlasRb is stubbed — the gated
# enumeration is specced elsewhere (set_resolver_spec / the request specs); here
# we own only "given these docs, what lands in the zip".
RSpec.describe MetadataExportPacker do
  # Minimal stand-in for a gated resolver: yields one page of Solr-shaped docs.
  let(:docs) do
    Class.new do
      def initialize(rows) = @rows = rows
      def each_content_batch(**) = yield @rows
    end.new([
              { 'alternate_ids_ssim' => ['id-aaa111'] },
              { 'alternate_ids_ssim' => ['id-bbb222'] }
            ])
  end

  before do
    allow(AtlasRb::Work).to receive(:mods) { |noid, _fmt| "<mods><id>#{noid}</id></mods>" }
  end

  # Pack into a buffer and return the entry-name => bytes map.
  def pack_to_entries(include_mods:)
    buffer = StringIO.new
    ZipKit::Streamer.open(buffer) do |zip|
      described_class.new(docs: docs, include_mods: include_mods).pack(zip)
    end
    buffer.rewind
    entries = {}
    Zip::File.open_buffer(buffer) do |archive|
      archive.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    entries
  end

  # Round-trip the bundled manifest.xlsx back through the loader's own parser.
  def manifest_rows(xlsx_bytes)
    file = Tempfile.new(['manifest', '.xlsx'])
    file.binmode
    file.write(xlsx_bytes)
    file.close
    XmlLoader::Manifest.new(file.path).rows
  ensure
    file&.unlink
  end

  context 'with MODS included (the default)' do
    let(:entries) { pack_to_entries(include_mods: true) }

    it 'writes one mods/<noid>.xml per item with the fetched XML' do
      expect(entries['mods/aaa111.xml']).to eq('<mods><id>aaa111</id></mods>')
      expect(entries['mods/bbb222.xml']).to eq('<mods><id>bbb222</id></mods>')
    end

    it 'writes a manifest.xlsx that re-parses through XmlLoader::Manifest' do
      rows = manifest_rows(entries.fetch('manifest.xlsx'))

      expect(rows.map(&:identifier)).to eq(%w[aaa111 bbb222])
      expect(rows.map(&:xml_path)).to eq(['mods/aaa111.xml', 'mods/bbb222.xml'])
      # Every exported row carries a NOID → the loader treats it as an update.
      expect(rows).to all(be_update)
    end

    it 'omits ERRORS.txt when every fetch succeeds' do
      expect(entries).not_to have_key('ERRORS.txt')
    end
  end

  context 'with manifest only (mods=0)' do
    let(:entries) { pack_to_entries(include_mods: false) }

    it 'bundles the manifest but no MODS files' do
      expect(entries).to have_key('manifest.xlsx')
      expect(entries.keys).not_to include(a_string_matching(%r{\Amods/}))
    end

    it 'leaves the MODS XML File Path column blank' do
      rows = manifest_rows(entries.fetch('manifest.xlsx'))

      expect(rows.map(&:identifier)).to eq(%w[aaa111 bbb222])
      expect(rows.map(&:xml_path)).to all(be_nil)
    end

    it 'never calls Atlas for MODS' do
      pack_to_entries(include_mods: false)
      expect(AtlasRb::Work).not_to have_received(:mods)
    end
  end

  context 'when a MODS fetch fails mid-stream' do
    before do
      allow(AtlasRb::Work).to receive(:mods).with('aaa111', anything)
                                            .and_raise(Faraday::ConnectionFailed, 'boom')
      allow(AtlasRb::Work).to receive(:mods).with('bbb222', anything)
                                            .and_return('<mods/>')
    end

    let(:entries) { pack_to_entries(include_mods: true) }

    it 'records the failure in ERRORS.txt and keeps going' do
      expect(entries['ERRORS.txt']).to include('aaa111')
      expect(entries).to have_key('mods/bbb222.xml')
    end

    it 'still lists the failed item in the manifest with a blank path' do
      rows = manifest_rows(entries.fetch('manifest.xlsx'))
      failed = rows.find { |r| r.identifier == 'aaa111' }

      expect(failed.xml_path).to be_nil
    end
  end
end
