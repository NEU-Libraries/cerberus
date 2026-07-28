# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Embargo do
  describe '.active?' do
    it 'is true for a future date' do
      expect(described_class.active?((Date.current + 30).to_s)).to be(true)
    end

    it 'is false for a past date' do
      expect(described_class.active?((Date.current - 1).to_s)).to be(false)
    end

    it 'is false for today (release day is no longer withheld)' do
      expect(described_class.active?(Date.current.to_s)).to be(false)
    end

    it 'is false for blank, nil, or unparseable input' do
      expect(described_class.active?(nil)).to be(false)
      expect(described_class.active?('')).to be(false)
      expect(described_class.active?('not-a-date')).to be(false)
    end
  end

  describe '.release_date' do
    it 'parses a valid date string' do
      expect(described_class.release_date('2030-01-15')).to eq(Date.parse('2030-01-15'))
    end

    it 'returns nil for blank, nil, or unparseable input' do
      expect(described_class.release_date(nil)).to be_nil
      expect(described_class.release_date('')).to be_nil
      expect(described_class.release_date('not-a-date')).to be_nil
    end
  end
end
