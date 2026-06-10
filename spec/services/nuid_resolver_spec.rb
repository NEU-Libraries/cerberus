# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NuidResolver do
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  before { allow(Rails).to receive(:cache).and_return(memory_cache) }

  describe '.names_for' do
    it 'resolves via the Atlas directory and prettifies stored names' do
      allow(AtlasRb::User).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'name' => 'Cliff, David' },
         { 'nuid' => '000000003', 'name' => 'Doe, Jane' }]
      )

      expect(described_class.names_for(%w[000000002 000000003]))
        .to eq('000000002' => 'David Cliff', '000000003' => 'Jane Doe')
    end

    it 'falls back to the raw NUID for unresolvables (Atlas drops them silently)' do
      allow(AtlasRb::User).to receive(:resolve).and_return([{ 'nuid' => '000000002', 'name' => 'Cliff, David' }])

      expect(described_class.names_for(%w[000000002 ghost]))
        .to eq('000000002' => 'David Cliff', 'ghost' => 'ghost')
    end

    it 'serves repeat lookups from cache without re-calling Atlas' do
      allow(AtlasRb::User).to receive(:resolve).and_return([{ 'nuid' => '000000002', 'name' => 'Cliff, David' }])

      2.times { described_class.names_for(%w[000000002]) }

      expect(AtlasRb::User).to have_received(:resolve).once
    end

    it 'does not cache misses, so a later-provisioned user resolves immediately' do
      allow(AtlasRb::User).to receive(:resolve).and_return(
        [], [{ 'nuid' => '000000002', 'name' => 'Cliff, David' }]
      )

      expect(described_class.names_for(%w[000000002])).to eq('000000002' => '000000002')
      expect(described_class.names_for(%w[000000002])).to eq('000000002' => 'David Cliff')
    end

    it 'degrades to raw NUIDs when Atlas is unreachable' do
      allow(AtlasRb::User).to receive(:resolve).and_raise(Faraday::ConnectionFailed.new('boom'))

      expect(described_class.names_for(%w[000000002])).to eq('000000002' => '000000002')
    end

    it 'returns {} for empty input without calling Atlas' do
      allow(AtlasRb::User).to receive(:resolve)

      expect(described_class.names_for([nil])).to eq({})
      expect(AtlasRb::User).not_to have_received(:resolve)
    end
  end

  describe '.name_for' do
    it 'resolves a single NUID' do
      allow(AtlasRb::User).to receive(:resolve).and_return([{ 'nuid' => '000000002', 'name' => 'Cliff, David' }])

      expect(described_class.name_for('000000002')).to eq('David Cliff')
    end
  end

  describe '.prettify' do
    it 'reorders "Family, Given" into display order' do
      expect(described_class.prettify('Cliff, David')).to eq('David Cliff')
    end

    it 'passes through unparsable input untouched' do
      expect(described_class.prettify('')).to eq('')
    end
  end
end
