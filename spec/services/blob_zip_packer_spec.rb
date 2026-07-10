# frozen_string_literal: true

require 'rails_helper'

# Unit-level: the single-file packer's root placement / naming, with the Atlas
# content read stubbed. The zip-vs-raw branch and HTTP surface are covered in
# the downloads request spec. FakeZip (spec/support/fake_zip.rb) only responds
# to write_stored_file, so a regression away from STORE fails loudly here.
RSpec.describe BlobZipPacker do
  let(:zip) { FakeZip.new }

  def blob(noid:, filename: nil, original_filename: nil, mime_type: nil)
    AtlasRb::Mash.new('noid' => noid, 'filename' => filename,
                      'original_filename' => original_filename, 'mime_type' => mime_type)
  end

  def names = zip.entries.map(&:name)

  it 'streams the blob into a single root entry under its labeled filename' do
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('OPAQUEBYTES')

    described_class.new(asset: blob(noid: 'blob1', filename: 'data_blob1.bin')).pack(zip)

    expect(zip.entries.size).to eq(1)
    entry = zip.entries.first
    expect(entry.name).to eq('data_blob1.bin') # archive root — no per-work folder
    expect(entry.body).to eq('OPAQUEBYTES')
  end

  it 'names the entry <noid>.<ext> when unlabeled, never the original_filename' do
    allow(AtlasRb::Blob).to receive(:content).with('blob2').and_yield('x')

    described_class.new(asset: blob(noid: 'blob2', filename: nil,
                                    original_filename: 'UNHINGED name!!.dat')).pack(zip)

    expect(names).to eq(['blob2.dat'])
    expect(names).not_to include(a_string_matching(/UNHINGED/i))
  end

  it 'writes no MANIFEST.txt for a lone file' do
    allow(AtlasRb::Blob).to receive(:content).with('blob1').and_yield('x')

    described_class.new(asset: blob(noid: 'blob1', filename: 'data.bin')).pack(zip)

    expect(names).not_to include('MANIFEST.txt')
  end
end
