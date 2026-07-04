# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaRange do
  describe '.parse' do
    it 'parses a closed range' do
      r = described_class.parse('bytes=0-499', 1000)
      expect([r.start, r.finish, r.total, r.length]).to eq([0, 499, 1000, 500])
      expect(r.content_range).to eq('bytes 0-499/1000')
    end

    it 'treats an open-ended range as through the last byte' do
      r = described_class.parse('bytes=500-', 1000)
      expect([r.start, r.finish]).to eq([500, 999])
    end

    it 'clamps an end beyond the file to the last byte' do
      r = described_class.parse('bytes=0-99999', 1000)
      expect(r.finish).to eq(999)
    end

    it 'resolves a suffix range to the final N bytes' do
      r = described_class.parse('bytes=-200', 1000)
      expect([r.start, r.finish]).to eq([800, 999])
    end

    it 'returns nil for no/blank header, malformed, or unknown size' do
      expect(described_class.parse(nil, 1000)).to be_nil
      expect(described_class.parse('bytes=abc', 1000)).to be_nil
      expect(described_class.parse('bytes=0-499', nil)).to be_nil
    end

    it 'returns nil for an unsatisfiable range (start past the end)' do
      expect(described_class.parse('bytes=2000-', 1000)).to be_nil
    end
  end
end
