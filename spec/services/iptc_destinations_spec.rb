# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IptcDestinations do
  subject(:destinations) { described_class.call(root: 'root1') }

  def node(noid, klass: 'Collection', tombstoned: false)
    AtlasRb::Mash.new('noid' => noid, 'klass' => klass, 'title' => noid.upcase, 'tombstoned' => tombstoned)
  end

  before { allow(AtlasRb::Collection).to receive(:children).with('root1').and_return(%w[c2 w1 c1 c3]) }

  it 'offers live Collections only, in the children order' do
    allow(AtlasRb::Resource).to receive(:find_many)
      .and_return([node('c1'), node('w1', klass: 'Work'), node('c3', tombstoned: true), node('c2')])

    expect(destinations.pluck('noid')).to eq(%w[c2 c1])
  end

  # The New upload page renders this list, so a failed read must not 500 it.
  it 'reads an Atlas error as no destinations' do
    allow(AtlasRb::Resource).to receive(:find_many).and_raise(AtlasRb::ResourceError.new('boom'))

    expect(destinations).to eq([])
  end

  it 'reads a 404 from find_many as no destinations' do
    allow(AtlasRb::Resource).to receive(:find_many).and_return(nil)

    expect(destinations).to eq([])
  end
end
