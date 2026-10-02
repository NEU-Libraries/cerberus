# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadDestination do
  def loader(kind)
    Loader.new(slug: kind, kind: kind, display_name: kind, group: 'g', root_collection: 'root1')
  end

  def mash(noid, klass: 'Collection')
    AtlasRb::Mash.new('noid' => noid, 'klass' => klass, 'title' => noid)
  end

  describe 'an IPTC loader' do
    before do
      allow(AtlasRb::Collection).to receive(:children).with('root1').and_return(%w[c1])
      allow(AtlasRb::Resource).to receive(:find_many).with(%w[c1]).and_return([mash('c1')])
    end

    it 'accepts a Collection its dropdown lists' do
      expect(described_class.call(loader: loader('iptc'), parent_id: 'c1')).to be(true)
    end

    # A real Collection, but not under this loader's root.
    it 'refuses a Collection its dropdown does not list' do
      expect(described_class.call(loader: loader('iptc'), parent_id: 'c9')).to be(false)
    end

    it 'refuses a blank destination' do
      expect(described_class.call(loader: loader('iptc'), parent_id: '')).to be(false)
    end

    it 'refuses everything when Atlas cannot list the destinations' do
      allow(AtlasRb::Resource).to receive(:find_many).and_raise(Faraday::ConnectionFailed.new('down'))

      expect(described_class.call(loader: loader('iptc'), parent_id: 'c1')).to be(false)
    end
  end

  describe 'an XML or multipage loader' do
    it 'accepts any Collection' do
      allow(AtlasRb::Resource).to receive(:find).with('c9').and_return(mash('c9'))

      expect(described_class.call(loader: loader('multipage'), parent_id: 'c9')).to be(true)
    end

    it 'refuses a Work' do
      allow(AtlasRb::Resource).to receive(:find).with('w1').and_return(mash('w1', klass: 'Work'))

      expect(described_class.call(loader: loader('xml'), parent_id: 'w1')).to be(false)
    end

    it 'refuses an unknown NOID' do
      allow(AtlasRb::Resource).to receive(:find).with('nope').and_return(nil)

      expect(described_class.call(loader: loader('xml'), parent_id: 'nope')).to be(false)
    end

    # An overwrite package names its own Works, so only XML may leave it blank.
    it 'leaves a blank destination to the XML preview, but not to multipage' do
      expect(described_class.call(loader: loader('xml'), parent_id: '')).to be(true)
      expect(described_class.call(loader: loader('multipage'), parent_id: '')).to be(false)
    end
  end
end
