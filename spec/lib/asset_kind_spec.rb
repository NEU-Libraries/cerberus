# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssetKind do
  it 'reads a Delegate from its kind' do
    expect(described_class.delegate?(AtlasRb::Mash.new('kind' => 'Delegate', 'uri' => 'https://iiif/x'))).to be(true)
  end

  # Under an embargo Atlas nulls a gated Delegate's uri for a caller below staff
  # with no edit grant. It is still a Delegate.
  it 'reads a Delegate whose uri an embargo nulled' do
    asset = AtlasRb::Mash.new(JSON.parse('{"kind":"Delegate","role":"large_image","uri":null}'))

    expect(described_class.delegate?(asset)).to be(true)
    expect(described_class.blob?(asset)).to be(false)
  end

  it 'reads a Blob from its kind' do
    expect(described_class.blob?(AtlasRb::Mash.new('kind' => 'Blob', 'noid' => 'b-1'))).to be(true)
  end

  it 'counts an entry with no kind as a Blob' do
    expect(described_class.blob?(AtlasRb::Mash.new('noid' => 'b-1'))).to be(true)
  end

  it 'reads a plain symbol-keyed hash the same way' do
    expect(described_class.delegate?({ kind: 'Delegate' })).to be(true)
  end
end
