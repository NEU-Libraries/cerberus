# frozen_string_literal: true

require 'rails_helper'

describe TombstoneReasons do
  describe '.sentence' do
    let(:reason) { "Removed from view at Northeastern University Library's discretion" }

    it 'joins the reason and the withdrawal date into one sentence' do
      expect(described_class.sentence('Sample Report', reason, '2026-09-30T14:05:00Z'))
        .to eq("\"Sample Report\" was removed from view at Northeastern University Library's " \
               'discretion on September 30, 2026.')
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

  it 'records the curator note for a non-admin withdrawal' do
    expect(described_class::CURATOR).to eq("Removed from view at contributor or content curator's discretion")
  end
end
