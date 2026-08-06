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

  describe '.search' do
    before do
      described_class.create!(raw:      'northeastern:drs:repository:loaders:marcom',
                              cosmetic: 'Marketing and Communications')
      described_class.create!(raw:      'northeastern:drs:school_of_law:law_library:staff',
                              cosmetic: 'Law Library Staff')
    end

    it 'matches part of the raw identifier' do
      expect(described_class.search('marcom').pluck(:cosmetic)).to eq(['Marketing and Communications'])
    end

    it 'matches part of the display name' do
      expect(described_class.search('Law Library').pluck(:cosmetic)).to eq(['Law Library Staff'])
    end

    it 'ignores case' do
      expect(described_class.search('MARCOM').count).to eq(1)
    end

    it 'ignores surrounding whitespace' do
      expect(described_class.search('  marcom  ').count).to eq(1)
    end

    it 'returns every row for a blank term' do
      expect(described_class.search('').count).to eq(2)
      expect(described_class.search(nil).count).to eq(2)
    end

    # `%` and `_` are LIKE wildcards but ordinary characters in a Grouper
    # identifier, so an unescaped term would match every row. Escaped, `%`
    # matches nothing (no fixture contains one) and `_` matches only the row
    # whose identifier really carries an underscore.
    it 'treats a LIKE wildcard as a literal character' do
      expect(described_class.search('%').count).to eq(0)
      expect(described_class.search('_').pluck(:cosmetic)).to eq(['Law Library Staff'])
    end
  end

  describe '.for_select' do
    before do
      described_class.create!(raw: 'northeastern:drs:repository:zzz', cosmetic: 'Alpha Group')
      described_class.create!(raw: 'northeastern:drs:repository:aaa', cosmetic: 'Beta Group')
    end

    it 'returns [raw, cosmetic] pairs ordered by cosmetic name, not raw' do
      expect(described_class.for_select).to eq(
        [['northeastern:drs:repository:zzz', 'Alpha Group'],
         ['northeastern:drs:repository:aaa', 'Beta Group']]
      )
    end
  end
end
