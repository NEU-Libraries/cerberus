# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeaturedContent do
  describe '.picker_order' do
    it 'lists every genre A to Z with the catch-all last' do
      expect(described_class.picker_order(described_class.genre_labels)).to eq(
        ['Datasets', 'Monographs', 'Presentations', 'Research Publications',
         'Technical Reports', 'Theses & Dissertations', 'Other Publications']
      )
    end

    it 'ignores case' do
      expect(described_class.picker_order(%w[beta Alpha])).to eq(%w[Alpha beta])
    end

    it 'sorts a subset without adding the missing labels' do
      expect(described_class.picker_order(['Other Publications', 'Presentations', 'Datasets']))
        .to eq(['Datasets', 'Presentations', 'Other Publications'])
    end

    it 'leaves GENRES in its own order' do
      expect(described_class.genre_labels.first).to eq('Research Publications')
    end
  end
end
