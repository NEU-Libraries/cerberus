# frozen_string_literal: true

require 'rails_helper'

# Unit-level: the packer's filtering / naming / manifest logic, with the
# resolver and Atlas reads stubbed. (The gated enumeration is specced against
# real Solr in set_resolver_spec; the HTTP/auth surface in the request spec.)
RSpec.describe SetZipPacker do
  # Minimal stand-in for zip_kit's writer: records each stored entry's name and
  # the bytes pushed into its sink. Only responds to write_stored_file, so a
  # regression to write_file/write_deflated_file (i.e. losing STORE) would fail
  # loudly here rather than silently re-compress.
  class FakeZip
    Entry = Struct.new(:name, :body)
    attr_reader :entries

    def initialize = @entries = []

    def write_stored_file(name)
      sink = +''
      yield sink
      entries << Entry.new(name, sink)
    end
  end

  let(:zip) { FakeZip.new }
  let(:resolver) { instance_double(SetResolver) }
  let(:packer) { described_class.new(resolver: resolver, nuid: '000000002') }

  def work_doc(noid, title)
    SolrDocument.new('alternate_ids_ssim' => ["id-#{noid}"], 'title_tsim' => [title])
  end

  def blob(noid:, filename: nil, original_filename: nil, mime_type: nil)
    AtlasRb::Mash.new('noid' => noid, 'filename' => filename,
                      'original_filename' => original_filename, 'mime_type' => mime_type)
  end

  def delegate(noid:, uri:, use: 'Large Image')
    AtlasRb::Mash.new('noid' => noid, 'uri' => uri, 'use' => use)
  end

  def names = zip.entries.map(&:name)

  before { allow(resolver).to receive(:each_content_batch).and_yield([work_doc('bc1234', 'Smith Thesis')]) }

  it 'streams a content Blob into a per-work folder under its labeled filename' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
      .and_return([blob(noid: 'blob1', filename: 'pdf_blob1.pdf', mime_type: 'application/pdf')])
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('PDFBYTES')

    packer.pack(zip)

    entry = zip.entries.find { |e| e.name == 'smith-thesis-bc1234/pdf_blob1.pdf' }
    expect(entry).to be_present
    expect(entry.body).to eq('PDFBYTES')
  end

  it 'excludes Delegate-backed derivatives (they carry a uri)' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
      .and_return([blob(noid: 'blob1', filename: 'pdf_blob1.pdf'),
                   delegate(noid: 'del1', uri: 'https://iiif.example/large')])
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('x')

    packer.pack(zip)

    expect(names).to include('smith-thesis-bc1234/pdf_blob1.pdf')
    expect(names).not_to include(a_string_matching(/del1/))
    expect(AtlasRb::Blob).not_to have_received(:content).with('del1')
  end

  it 'falls back to a neutral <noid>.<ext> when the labeled filename is absent, never the original_filename' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
      .and_return([blob(noid: 'blob2', filename: nil, original_filename: 'UNHINGED name!!.tiff', mime_type: 'image/tiff')])
    allow(AtlasRb::Blob).to receive(:content).with('blob2').and_yield('x')

    packer.pack(zip)

    expect(names).to include('smith-thesis-bc1234/blob2.tiff')
    expect(names).not_to include(a_string_matching(/UNHINGED/i))
  end

  it 'writes a trailing MANIFEST.txt listing the packed entries' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
      .and_return([blob(noid: 'blob1', filename: 'pdf_blob1.pdf')])
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('x')

    packer.pack(zip)

    manifest = zip.entries.find { |e| e.name == 'MANIFEST.txt' }
    expect(manifest).to be_present
    expect(manifest.body).to include('smith-thesis-bc1234/pdf_blob1.pdf')
    expect(zip.entries.last.name).to eq('MANIFEST.txt') # written last
  end

  it 'records a mid-stream fetch failure in ERRORS.txt rather than aborting the archive' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
      .and_return([blob(noid: 'blob1', filename: 'pdf_blob1.pdf')])
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_raise(Faraday::TimeoutError)

    packer.pack(zip)

    errors = zip.entries.find { |e| e.name == 'ERRORS.txt' }
    expect(errors).to be_present
    expect(errors.body).to include('blob1')
  end
end
