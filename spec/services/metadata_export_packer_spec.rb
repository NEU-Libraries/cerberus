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
    allow(AtlasRb::Work).to receive(:assets).and_return([])
  end

  # The librarians found the File Name column always blank. It carries the name
  # the content file was deposited under; the loader ignores it on an update row.
  context 'the File Name column' do
    def asset(role:, original: nil, stored: nil, uri: nil)
      AtlasRb::Mash.new('role' => role, 'original_filename' => original, 'filename' => stored, 'uri' => uri)
    end

    def file_names
      manifest_rows(pack_to_entries(include_mods: false).fetch('manifest.xlsx')).to_h { |r| [r.identifier, r.file_name] }
    end

    it 'names the original file as deposited, not a derivative or the stored name' do
      derivative = asset(role: 'small_image', uri: 'https://iiif/x')
      original = asset(role: 'original_file', original: 'IMG_0042.jpg', stored: 'original_aaa.jpg')
      allow(AtlasRb::Work).to receive(:assets).with('aaa111').and_return([derivative, original])

      expect(file_names['aaa111']).to eq('IMG_0042.jpg')
    end

    it 'falls back to the stored name when none was recorded' do
      allow(AtlasRb::Work).to receive(:assets).with('aaa111')
                                              .and_return([asset(role: 'original_file', stored: 'original_aaa.jpg')])

      expect(file_names['aaa111']).to eq('original_aaa.jpg')
    end

    it 'leaves the cell blank and notes it when the file list cannot be read' do
      allow(AtlasRb::Work).to receive(:assets).with('aaa111').and_raise(Faraday::ConnectionFailed, 'down')

      entries = pack_to_entries(include_mods: false)
      expect(manifest_rows(entries.fetch('manifest.xlsx')).find { |r| r.identifier == 'aaa111' }.file_name).to be_nil
      expect(entries['ERRORS.txt']).to include('aaa111: file list fetch failed')
    end
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

  def manifest_headers(xlsx_bytes)
    file = Tempfile.new(['manifest', '.xlsx'])
    file.binmode
    file.write(xlsx_bytes)
    file.close
    sheet = Roo::Excelx.new(file.path)
    sheet.row(sheet.first_row)
  ensure
    file&.unlink
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
      expect(manifest_headers(entries.fetch('manifest.xlsx'))).to eq(described_class::HEADERS)
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

    # There is no MODS file to point at, so the column is left out rather than
    # left blank. The loader finds columns by label, so the rest still parse.
    it 'leaves out the MODS XML File Path column' do
      expect(manifest_headers(entries.fetch('manifest.xlsx')))
        .to eq(['PIDs', 'File Name', 'Embargoed?', 'Embargo Date', 'Date Ingested'])

      rows = manifest_rows(entries.fetch('manifest.xlsx'))
      expect(rows.map(&:identifier)).to eq(%w[aaa111 bbb222])
      expect(rows.map(&:xml_path)).to all(be_nil)
    end

    it 'never calls Atlas for MODS' do
      pack_to_entries(include_mods: false)
      expect(AtlasRb::Work).not_to have_received(:mods)
    end
  end

  context 'the Date Ingested column' do
    let(:docs) do
      Class.new do
        def initialize(rows) = @rows = rows
        def each_content_batch(**) = yield @rows
      end.new([
                # 02:30 UTC on the 16th is still the 15th in Boston.
                { 'alternate_ids_ssim' => ['id-aaa111'], 'created_at_dtsi' => '2026-07-16T02:30:00Z' },
                { 'alternate_ids_ssim' => ['id-bbb222'] }
              ])
    end
    let(:entries) { pack_to_entries(include_mods: false) }

    def sheet_rows(xlsx_bytes)
      file = Tempfile.new(['manifest', '.xlsx'])
      file.binmode
      file.write(xlsx_bytes)
      file.close
      sheet = Roo::Excelx.new(file.path).sheet(0)
      (1..sheet.last_row).map { |i| sheet.row(i) }
    ensure
      file&.unlink
    end

    it 'follows the loader columns and gives each Work its Eastern ingest date' do
      header, first, second = sheet_rows(entries.fetch('manifest.xlsx'))

      expect(header.last).to eq('Date Ingested')
      expect(first.last).to eq('2026-07-15')
      expect(second.last).to be_nil
    end

    it 'still re-parses through the loader, which ignores the extra column' do
      expect(manifest_rows(entries.fetch('manifest.xlsx')).map(&:identifier)).to eq(%w[aaa111 bbb222])
    end
  end

  context 'embargo columns' do
    let(:docs) do
      Class.new do
        def initialize(rows) = @rows = rows
        def each_content_batch(**) = yield @rows
      end.new([
                { 'alternate_ids_ssim' => ['id-aaa111'], 'embargo_release_date_dtsi' => 1.year.from_now.to_date.iso8601 },
                { 'alternate_ids_ssim' => ['id-bbb222'], 'embargo_release_date_dtsi' => '2020-07-16',
                  'embargoed_bsi' => 'true' },
                { 'alternate_ids_ssim' => ['id-ccc333'] }
              ])
    end
    let(:entries) { pack_to_entries(include_mods: false) }

    def row_for(entries, identifier)
      manifest_rows(entries.fetch('manifest.xlsx')).find { |r| r.identifier == identifier }
    end

    it 'marks a row embargoed while its release date is in the future' do
      row = row_for(entries, 'aaa111')
      expect(row.embargoed?).to be(true)
      expect(row.embargo_date).to eq(1.year.from_now.to_date.iso8601)
    end

    # The date stays, because it is still a fact about the Work. A stale
    # `embargoed_bsi` left in the index must not override it.
    it 'leaves Embargoed? blank once the release date has passed' do
      row = row_for(entries, 'bbb222')
      expect(row.embargoed?).to be(false)
      expect(row.embargo_date).to eq('2020-07-16')
    end

    it 'leaves a non-embargoed row blank' do
      row = row_for(entries, 'ccc333')
      expect(row.embargoed?).to be(false)
      expect(row.embargo_date).to be_nil
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
