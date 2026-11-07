# frozen_string_literal: true

require 'rails_helper'

describe TombstoneReasons do
  describe '.sentence' do
    let(:reason) { "Removed from view at Northeastern University Library's discretion" }

    it 'joins the reason and the tombstone date into one sentence' do
      expect(described_class.sentence('Sample Report', reason, '2026-09-30T14:05:00Z'))
        .to eq("\"Sample Report\" was removed from view at Northeastern University Library's " \
               'discretion on September 30, 2026.')
    end

    it 'does not pad a single-digit day' do
      expect(described_class.sentence('Sample Report', reason, '2026-10-01T14:05:00Z')).to end_with('on October 1, 2026.')
    end

    it 'drops the date when Atlas sent none, or one that does not parse' do
      expected = "\"Sample Report\" was removed from view at Northeastern University Library's discretion."
      expect(described_class.sentence('Sample Report', reason, nil)).to eq(expected)
      expect(described_class.sentence('Sample Report', reason, 'not-a-date')).to eq(expected)
    end

    it 'falls back to a plain removal when no reason was recorded' do
      expect(described_class.sentence('Sample Report', nil, '2026-09-30T14:05:00Z'))
        .to eq('"Sample Report" has been removed.')
    end
  end

  describe '.headline' do
    it 'gives a purged item its purge date and no title' do
      record = AtlasRb::Mash.new('id' => 'p1', 'purged' => true, 'purged_at' => '2026-11-06T18:30:00Z')
      expect(described_class.headline(record, 'p1')).to eq('This item was removed on November 6, 2026.')
    end

    it 'drops a purge date that does not parse' do
      record = AtlasRb::Mash.new('id' => 'p1', 'purged' => true, 'purged_at' => 'not-a-date')
      expect(described_class.headline(record, 'p1')).to eq('This item was removed.')
    end

    it 'names a tombstoned item by its title' do
      record = AtlasRb::Mash.new('title' => 'Sample Report', 'tombstoned' => true)
      expect(described_class.headline(record, 'Sample Report')).to eq('"Sample Report" has been removed.')
    end
  end

  it 'records the curator note for a non-admin tombstone' do
    expect(described_class::CURATOR).to eq("Removed from view at contributor or content curator's discretion")
  end
end
