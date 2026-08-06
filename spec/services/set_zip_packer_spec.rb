# frozen_string_literal: true

require 'rails_helper'

# Unit-level: the packer's filtering / naming / manifest logic, with the
# resolver and Atlas reads stubbed. (The gated enumeration is specced against
# real Solr in set_resolver_spec; the HTTP/auth surface in the request spec.)
RSpec.describe SetZipPacker do
  # FakeZip lives in spec/support/fake_zip.rb (shared with queue_zip_packer_spec).
  let(:zip) { FakeZip.new }
  let(:resolver) { instance_double(SetResolver) }
  let(:packer) { described_class.new(resolver: resolver, nuid: '000000002') }

  def work_doc(noid, embargo: nil)
    SolrDocument.new('alternate_ids_ssim'        => ["id-#{noid}"],
                     'embargo_release_date_dtsi' => embargo)
  end

  def blob(noid:, filename: nil, original_filename: nil, mime_type: nil)
    AtlasRb::Mash.new('noid' => noid, 'filename' => filename,
                      'original_filename' => original_filename, 'mime_type' => mime_type)
  end

  def delegate(noid:, uri:, use: 'Large Image')
    AtlasRb::Mash.new('noid' => noid, 'uri' => uri, 'use' => use)
  end

  def names = zip.entries.map(&:name)

  before { allow(resolver).to receive(:each_content_batch).and_yield([work_doc('bc1234')]) }

  # The set's gated search cannot filter these out: an embargoed Work is
  # deliberately DISCOVERABLE — public metadata, withheld content — so it clears
  # discovery and reaches the packer. Without the per-file check the archive is
  # built with the set OWNER's reach and hands an anonymous caller bytes that
  # /downloads/:id refuses them.
  context 'when a member work is under an active embargo' do
    before do
      allow(resolver).to receive(:each_content_batch)
        .and_yield([work_doc('work1', embargo: (Date.current + 30).to_s)])
      allow(AtlasRb::Work).to receive(:assets)
        .and_return([blob(noid: 'blobA', filename: 'a.jpg', mime_type: 'image/jpeg')])
    end

    it 'packs none of its bytes for a caller who cannot bypass' do
      described_class.new(resolver: resolver, nuid: nil).pack(zip)
      expect(names).not_to include('work1/a.jpg')
    end

    it 'names it as withheld rather than dropping it silently' do
      described_class.new(resolver: resolver, nuid: nil).pack(zip)
      expect(names).to include('ERRORS.txt')
    end

    it 'packs it for a caller who may bypass' do
      described_class.new(resolver: resolver, nuid: '000000006', bypass_embargo: true).pack(zip)
      expect(names).to include('work1/a.jpg')
    end

    it 'does not even ask Atlas for assets it will not pack' do
      described_class.new(resolver: resolver, nuid: nil).pack(zip)
      expect(AtlasRb::Work).not_to have_received(:assets)
    end
  end

  it 'streams a content Blob into a per-work folder under its labeled filename' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
                                            .and_return([blob(noid: 'blob1', filename: 'pdf_blob1.pdf', mime_type: 'application/pdf')])
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('PDFBYTES')

    packer.pack(zip)

    entry = zip.entries.find { |e| e.name == 'bc1234/pdf_blob1.pdf' }
    expect(entry).to be_present
    expect(entry.body).to eq('PDFBYTES')
  end

  it 'excludes Delegate-backed derivatives (they carry a uri)' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
                                            .and_return([blob(noid: 'blob1', filename: 'pdf_blob1.pdf'),
                                                         delegate(noid: 'del1', uri: 'https://iiif.example/large')])
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('x')

    packer.pack(zip)

    expect(names).to include('bc1234/pdf_blob1.pdf')
    expect(names).not_to include(a_string_matching(/del1/))
    expect(AtlasRb::Blob).not_to have_received(:content).with('del1')
  end

  it 'falls back to a neutral <noid>.<ext> when the labeled filename is absent, never the original_filename' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
                                            .and_return([blob(noid: 'blob2', filename: nil, original_filename: 'UNHINGED name!!.tiff', mime_type: 'image/tiff')])
    allow(AtlasRb::Blob).to receive(:content).with('blob2').and_yield('x')

    packer.pack(zip)

    expect(names).to include('bc1234/blob2.tiff')
    expect(names).not_to include(a_string_matching(/UNHINGED/i))
  end

  it 'writes a trailing MANIFEST.txt listing the packed entries' do
    allow(AtlasRb::Work).to receive(:assets).with('bc1234', nuid: '000000002')
                                            .and_return([blob(noid: 'blob1', filename: 'pdf_blob1.pdf')])
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('x')

    packer.pack(zip)

    manifest = zip.entries.find { |e| e.name == 'MANIFEST.txt' }
    expect(manifest).to be_present
    expect(manifest.body).to include('bc1234/pdf_blob1.pdf')
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
