# frozen_string_literal: true

require 'rails_helper'

# Unit-level: packs only the queued blobs, grouped into per-work folders, with
# Atlas reads stubbed. (FakeZip is in spec/support.)
RSpec.describe QueueZipPacker do
  let(:zip) { FakeZip.new }
  # These fixtures' assets carry no gate, so DerivativeGate resolves them public
  # and a guest ability reads them. The tier gate has its own examples below.
  let(:ability) { Ability.new(nil) }

  def blob(noid:, filename: nil, original_filename: nil, mime_type: nil)
    AtlasRb::Mash.new('noid' => noid, 'filename' => filename,
                      'original_filename' => original_filename, 'mime_type' => mime_type)
  end

  def delegate(noid:, uri:)
    AtlasRb::Mash.new('noid' => noid, 'uri' => uri, 'use' => 'Large Image')
  end

  def names = zip.entries.map(&:name)

  # The embargo check costs one permissions read per distinct work. Unembargoed
  # by default, so the packing examples below stay about packing.
  before do
    allow(AtlasRb::Resource).to receive(:permissions).and_return(AtlasRb::Mash.new('embargo' => ''))
  end

  # Work.assets re-checks READ, and an embargoed Work is readable on purpose —
  # so its assets come back and would be packed without this.
  context 'when a queued work is under an active embargo' do
    let(:items) { [{ 'w' => 'work1', 'b' => 'blobA' }] }

    before do
      allow(AtlasRb::Resource).to receive(:permissions)
        .with('work1').and_return(AtlasRb::Mash.new('embargo' => (Date.current + 30).to_s))
      allow(AtlasRb::Work).to receive(:assets)
        .and_return([blob(noid: 'blobA', filename: 'pdf_blobA.pdf', mime_type: 'application/pdf')])
    end

    it 'packs none of its bytes for a caller who cannot bypass' do
      described_class.new(items: items, nuid: nil, ability: ability).pack(zip)
      expect(names).not_to include('work1/pdf_blobA.pdf')
    end

    it 'names it as withheld rather than dropping it silently' do
      described_class.new(items: items, nuid: nil, ability: ability).pack(zip)
      expect(zip.entries.map(&:name)).to include('ERRORS.txt')
    end

    it 'packs it for a caller who may bypass' do
      described_class.new(items: items, nuid: '000000006', ability: ability, bypass_embargo: true).pack(zip)
      expect(names).to include('work1/pdf_blobA.pdf')
    end
  end

  it 'packs only the queued blobs of a work, into its noid folder, with labeled names' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }] # blobB is NOT queued
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: '000000002').and_return(
      [blob(noid: 'blobA', filename: 'pdf_blobA.pdf'), blob(noid: 'blobB', filename: 'pdf_blobB.pdf')]
    )
    allow(AtlasRb::Blob).to receive(:content).with('blobA').and_yield('A')

    described_class.new(items: items, nuid: '000000002', ability: ability).pack(zip)

    expect(names).to include('work1/pdf_blobA.pdf')
    expect(names).not_to include('work1/pdf_blobB.pdf')
  end

  it 'groups queued blobs from different works into separate folders' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }, { 'w' => 'work2', 'b' => 'blobC' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_return([blob(noid: 'blobA', filename: 'a.jpg')])
    allow(AtlasRb::Work).to receive(:assets).with('work2', nuid: nil).and_return([blob(noid: 'blobC', filename: 'c.jpg')])
    allow(AtlasRb::Blob).to receive(:content).with('blobA').and_yield('a')
    allow(AtlasRb::Blob).to receive(:content).with('blobC').and_yield('c')

    described_class.new(items: items, nuid: nil, ability: ability).pack(zip)

    expect(names).to include('work1/a.jpg', 'work2/c.jpg')
  end

  it 'skips a BLOB-keyed id that resolves to a Delegate, never fetching content' do
    # A `'b'` entry is content-only; if its noid resolves to a delegate it is
    # skipped. (Derivatives are queued as `'d'` entries — see below.)
    items = [{ 'w' => 'work1', 'b' => 'del1' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil)
                                            .and_return([delegate(noid: 'del1', uri: 'https://iiif.example/large')])
    allow(AtlasRb::Blob).to receive(:content)

    described_class.new(items: items, nuid: nil, ability: ability).pack(zip)

    expect(names).to eq(['MANIFEST.txt'])
    expect(AtlasRb::Blob).not_to have_received(:content)
  end

  it 'packs a queued derivative rendition by fetching its signed IIIF URL' do
    items = [{ 'w' => 'work1', 'd' => 'Large Image' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_return(
      [delegate(noid: 'del1', uri: 'https://iiif.example/iiif/3/gated-x.jp2/full/pct:75/0/default.jpg')]
    )
    allow(IiifSigner).to receive(:sign_url).and_return('https://iiif.example/signed')
    allow(Faraday).to receive(:get) # no real HTTP; the chunk stream is Faraday's job

    described_class.new(items: items, nuid: nil, ability: ability).pack(zip)

    expect(names).to include('work1/large-image.jpg')
    expect(Faraday).to have_received(:get).with('https://iiif.example/signed')
  end

  it 'skips a derivative whose use is not the queued one' do
    items = [{ 'w' => 'work1', 'd' => 'Large Image' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_return(
      [AtlasRb::Mash.new('noid' => 'd2', 'uri' => 'https://iiif.example/small', 'use' => 'Small Image')]
    )
    allow(Faraday).to receive(:get)

    described_class.new(items: items, nuid: nil, ability: ability).pack(zip)

    expect(names).to eq(['MANIFEST.txt'])
    expect(Faraday).not_to have_received(:get)
  end

  it 'records a failed work assets fetch in ERRORS.txt rather than aborting' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_raise(Faraday::TimeoutError)

    described_class.new(items: items, nuid: nil, ability: ability).pack(zip)

    errors = zip.entries.find { |e| e.name == 'ERRORS.txt' }
    expect(errors).to be_present
    expect(errors.body).to include('work1')
  end

  it 'writes a trailing MANIFEST.txt' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_return([blob(noid: 'blobA', filename: 'a.jpg')])
    allow(AtlasRb::Blob).to receive(:content).with('blobA').and_yield('a')

    described_class.new(items: items, nuid: nil, ability: ability).pack(zip)

    expect(zip.entries.last.name).to eq('MANIFEST.txt')
  end
end
