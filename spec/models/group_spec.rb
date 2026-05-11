# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Group, type: :model do
  it 'inherits from ApplicationRecord' do
    expect(described_class.superclass).to eq(ApplicationRecord)
  end

  describe 'attributes' do
    let(:group) { described_class.new(raw: 'northeastern:drs:repository:staff', cosmetic: 'DRS Staff') }

    it 'exposes the raw group identifier' do
      expect(group.raw).to eq('northeastern:drs:repository:staff')
    end

    it 'exposes the cosmetic display name' do
      expect(group.cosmetic).to eq('DRS Staff')
    end
  end

  describe '.find_by(raw:)' do
    let!(:group) do
      described_class.create!(raw: 'northeastern:drs:repository:staff', cosmetic: 'DRS Staff')
    end

    it 'returns the record matching the raw identifier' do
      expect(described_class.find_by(raw: 'northeastern:drs:repository:staff')).to eq(group)
    end

    it 'returns nil for an unknown identifier' do
      expect(described_class.find_by(raw: 'nope')).to be_nil
    end
  end
end
