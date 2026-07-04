# frozen_string_literal: true

require 'rails_helper'

# Unit-level: packs only the queued blobs, grouped into per-work folders, with
# Atlas reads stubbed. (FakeZip is in spec/support.)
RSpec.describe QueueZipPacker do
  let(:zip) { FakeZip.new }

  def blob(noid:, filename: nil, original_filename: nil, mime_type: nil)
    AtlasRb::Mash.new('noid' => noid, 'filename' => filename,
                      'original_filename' => original_filename, 'mime_type' => mime_type)
  end

  def delegate(noid:, uri:)
    AtlasRb::Mash.new('noid' => noid, 'uri' => uri, 'use' => 'Large Image')
  end

  def names = zip.entries.map(&:name)

  it 'packs only the queued blobs of a work, into its noid folder, with labeled names' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }] # blobB is NOT queued
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: '000000002').and_return(
      [blob(noid: 'blobA', filename: 'pdf_blobA.pdf'), blob(noid: 'blobB', filename: 'pdf_blobB.pdf')]
    )
    allow(AtlasRb::Blob).to receive(:content).with('blobA').and_yield('A')

    described_class.new(items: items, nuid: '000000002').pack(zip)

    expect(names).to include('work1/pdf_blobA.pdf')
    expect(names).not_to include('work1/pdf_blobB.pdf')
  end

  it 'groups queued blobs from different works into separate folders' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }, { 'w' => 'work2', 'b' => 'blobC' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_return([blob(noid: 'blobA', filename: 'a.jpg')])
    allow(AtlasRb::Work).to receive(:assets).with('work2', nuid: nil).and_return([blob(noid: 'blobC', filename: 'c.jpg')])
    allow(AtlasRb::Blob).to receive(:content).with('blobA').and_yield('a')
    allow(AtlasRb::Blob).to receive(:content).with('blobC').and_yield('c')

    described_class.new(items: items, nuid: nil).pack(zip)

    expect(names).to include('work1/a.jpg', 'work2/c.jpg')
  end

  it 'skips a queued id that resolves to a Delegate (derivative), never fetching it' do
    items = [{ 'w' => 'work1', 'b' => 'del1' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil)
                                            .and_return([delegate(noid: 'del1', uri: 'https://iiif.example/large')])
    allow(AtlasRb::Blob).to receive(:content)

    described_class.new(items: items, nuid: nil).pack(zip)

    expect(names).to eq(['MANIFEST.txt'])
    expect(AtlasRb::Blob).not_to have_received(:content)
  end

  it 'records a failed work assets fetch in ERRORS.txt rather than aborting' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_raise(Faraday::TimeoutError)

    described_class.new(items: items, nuid: nil).pack(zip)

    errors = zip.entries.find { |e| e.name == 'ERRORS.txt' }
    expect(errors).to be_present
    expect(errors.body).to include('work1')
  end

  it 'writes a trailing MANIFEST.txt' do
    items = [{ 'w' => 'work1', 'b' => 'blobA' }]
    allow(AtlasRb::Work).to receive(:assets).with('work1', nuid: nil).and_return([blob(noid: 'blobA', filename: 'a.jpg')])
    allow(AtlasRb::Blob).to receive(:content).with('blobA').and_yield('a')

    described_class.new(items: items, nuid: nil).pack(zip)

    expect(zip.entries.last.name).to eq('MANIFEST.txt')
  end
end
