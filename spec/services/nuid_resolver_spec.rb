# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NuidResolver do
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(memory_cache)
    # Default: no curated Person names, so tests exercise the SSO fallback
    # unless they opt into Person resolution explicitly.
    allow(AtlasRb::Person).to receive(:resolve).and_return([])
  end

  describe '.names_for' do
    it 'resolves via the Atlas directory and prettifies stored names' do
      allow(AtlasRb::User).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'name' => 'Cliff, David' },
         { 'nuid' => '000000003', 'name' => 'Doe, Jane' }]
      )

      expect(described_class.names_for(%w[000000002 000000003]))
        .to eq('000000002' => 'David Cliff', '000000003' => 'Jane Doe')
    end

    it 'prefers a curated Person display_name over the SSO name, verbatim' do
      allow(AtlasRb::Person).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'display_name' => 'Dr. David Q. Cliff' }]
      )
      allow(AtlasRb::User).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'name' => 'Cliff, David' }]
      )

      expect(described_class.names_for(%w[000000002]))
        .to eq('000000002' => 'Dr. David Q. Cliff')
    end

    it 'does not call the SSO directory when every NUID has a curated Person' do
      allow(AtlasRb::Person).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'display_name' => 'David Cliff' }]
      )
      allow(AtlasRb::User).to receive(:resolve)

      described_class.names_for(%w[000000002])
      expect(AtlasRb::User).not_to have_received(:resolve)
    end

    it 'falls back to the SSO name when a Person has a blank display_name' do
      allow(AtlasRb::Person).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'display_name' => '' }]
      )
      allow(AtlasRb::User).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'name' => 'Cliff, David' }]
      )

      expect(described_class.names_for(%w[000000002])).to eq('000000002' => 'David Cliff')
    end

    it 'mixes curated Person names with SSO fallbacks in one batch' do
      allow(AtlasRb::Person).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'display_name' => 'David Cliff' }]
      )
      allow(AtlasRb::User).to receive(:resolve).and_return(
        [{ 'nuid' => '000000003', 'name' => 'Doe, Jane' }]
      )

      expect(described_class.names_for(%w[000000002 000000003]))
        .to eq('000000002' => 'David Cliff', '000000003' => 'Jane Doe')
    end

    it 'degrades to SSO names when the Person endpoint errors' do
      allow(AtlasRb::Person).to receive(:resolve).and_raise(Faraday::ConnectionFailed.new('boom'))
      allow(AtlasRb::User).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'name' => 'Cliff, David' }]
      )

      expect(described_class.names_for(%w[000000002])).to eq('000000002' => 'David Cliff')
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
      allow(AtlasRb::Person).to receive(:resolve).and_raise(Faraday::ConnectionFailed.new('boom'))
      allow(AtlasRb::User).to receive(:resolve).and_raise(Faraday::ConnectionFailed.new('boom'))

      expect(described_class.names_for(%w[000000002])).to eq('000000002' => '000000002')
    end

    it 'returns {} for empty input without calling Atlas' do
      allow(AtlasRb::User).to receive(:resolve)

      expect(described_class.names_for([nil])).to eq({})
      expect(AtlasRb::User).not_to have_received(:resolve)
      expect(AtlasRb::Person).not_to have_received(:resolve)
    end
  end

  describe '.name_for' do
    it 'resolves a single NUID via the SSO directory' do
      allow(AtlasRb::User).to receive(:resolve).and_return([{ 'nuid' => '000000002', 'name' => 'Cliff, David' }])

      expect(described_class.name_for('000000002')).to eq('David Cliff')
    end

    it 'prefers the curated Person name' do
      allow(AtlasRb::Person).to receive(:resolve).and_return(
        [{ 'nuid' => '000000002', 'display_name' => 'D. Cliff' }]
      )

      expect(described_class.name_for('000000002')).to eq('D. Cliff')
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
