# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LegacyIdentifier do
  after(:all) { LegacyIdentifier.delete_all }

  let(:attrs) { { pid: 'neu:rx918554d', noid: 'tqjq4r2', object_type: 'work' } }

  it 'is valid with a pid, a noid and a known object_type' do
    expect(described_class.new(attrs)).to be_valid
  end

  %i[pid noid object_type].each do |field|
    it "requires #{field}" do
      expect(described_class.new(attrs.merge(field => nil))).not_to be_valid
    end
  end

  it 'requires the pid to be unique' do
    described_class.create!(attrs)
    expect(described_class.new(attrs.merge(noid: 'other'))).not_to be_valid
  end

  # The value drives which route the controller builds, so an unrecognised one
  # would reach the router as a nil path helper.
  it 'rejects an object_type it has no v2 route for' do
    expect(described_class.new(attrs.merge(object_type: 'employee'))).not_to be_valid
  end

  it 'accepts every object_type the controller can route' do
    described_class::OBJECT_TYPES.each do |type|
      record = described_class.new(attrs.merge(pid: "neu:#{type}", object_type: type))
      expect(record).to be_valid, "expected #{type} to be a valid object_type"
    end
  end

  describe '.for_pid' do
    before { described_class.create!(attrs) }

    it 'finds the mapping for a full v1 pid' do
      expect(described_class.for_pid('neu:rx918554d').noid).to eq('tqjq4r2')
    end

    it 'returns nil for a pid that was never migrated' do
      expect(described_class.for_pid('neu:doesnotexist')).to be_nil
    end

    # The controller passes whatever the router captured, and a route can match
    # with an empty segment; a blank lookup must not become a full-table scan
    # that returns an arbitrary row.
    it 'returns nil for a blank pid without querying' do
      expect(described_class.for_pid('')).to be_nil
      expect(described_class.for_pid(nil)).to be_nil
    end

    # The hand-rolled integer pids are not a discard population — neu:1 is the
    # root Northeastern University Community, the most important object in the
    # repository. It maps like any other.
    it 'handles a hand-rolled bare-integer pid' do
      described_class.create!(pid: 'neu:1', noid: '8w9gjsf', object_type: 'community')
      expect(described_class.for_pid('neu:1').object_type).to eq('community')
    end
  end
end
