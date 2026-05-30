# frozen_string_literal: true

require 'rails_helper'

describe Loader do
  let(:valid_attrs) do
    {
      slug:            'marcom',
      display_name:    'Marketing and Communications',
      group:           'northeastern:drs:repository:loaders:marcom',
      root_collection: 'neu:6240'
    }
  end

  describe 'validations' do
    it 'is valid with all required fields' do
      expect(described_class.new(valid_attrs)).to be_valid
    end

    %i[slug display_name group root_collection].each do |attr|
      it "requires #{attr}" do
        loader = described_class.new(valid_attrs.except(attr))
        expect(loader).not_to be_valid
        expect(loader.errors[attr]).to be_present
      end
    end

    it 'enforces slug uniqueness' do
      described_class.create!(valid_attrs)
      duplicate = described_class.new(valid_attrs.merge(display_name: 'Other'))
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug].join).to match(/taken/i)
    end

    it 'rejects slugs with uppercase or whitespace or special characters' do
      ['Marcom', 'mar com', 'marcom!', 'mar/com'].each do |bad|
        loader = described_class.new(valid_attrs.merge(slug: bad))
        expect(loader).not_to be_valid, "expected #{bad.inspect} to be invalid"
      end
    end

    it 'accepts slugs with dashes and underscores' do
      %w[college-of-engineering cps_loader marcom1].each do |good|
        expect(described_class.new(valid_attrs.merge(slug: good))).to be_valid
      end
    end
  end

  describe '#to_param' do
    it 'returns slug for URL helpers' do
      expect(described_class.new(slug: 'marcom').to_param).to eq('marcom')
    end
  end

  describe 'load_reports association' do
    let(:loader) { described_class.create!(valid_attrs) }

    it 'refuses to destroy when load_reports reference it' do
      LoadReport.create!(loader: loader, source_filename: 'x.zip', parent_collection_id: 'neu:c1')
      expect { loader.destroy }.not_to change(described_class, :count)
      expect(loader.errors[:base]).to be_present
    end

    it 'can be destroyed when no load_reports reference it' do
      loader # force the lazy let to create before the count baseline
      expect { loader.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe 'default ordering' do
    it 'orders by slug ascending' do
      described_class.create!(valid_attrs.merge(slug: 'zeta', group: 'g1', root_collection: 'c1', display_name: 'Z'))
      described_class.create!(valid_attrs.merge(slug: 'alpha', group: 'g2', root_collection: 'c2', display_name: 'A'))
      expect(described_class.pluck(:slug)).to eq(%w[alpha zeta])
    end
  end
end
