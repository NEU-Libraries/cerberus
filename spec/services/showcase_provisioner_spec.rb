# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShowcaseProvisioner do
  before do
    allow(AtlasRb::Collection).to receive(:mods).and_return('<mods/>')
    allow(Metadata::MODSMerge).to receive(:call).and_return('<mods titled/>')
    allow(Metadata::MODSMerge).to receive(:unchanged?).and_return(false)
    allow(AtlasRb::Collection).to receive(:update)
    allow(File).to receive(:write)
  end

  it 'creates one featured showcase per genre, keyed by label, titled after the genre' do
    allow(AtlasRb::Collection).to receive(:create) { |*, **| AtlasRb::Mash.new('id' => "sc-#{rand(1_000_000)}") }

    result = described_class.call(community_id: 'comm1')

    expect(AtlasRb::Collection).to have_received(:create)
      .with('comm1', featured: true).exactly(FeaturedContent::GENRES.size).times
    expect(result.keys).to match_array(FeaturedContent.genre_labels)
    expect(Metadata::MODSMerge).to have_received(:call).with(hash_including(title: 'Datasets')).at_least(:once)
  end

  it 'skips a showcase whose create fails without aborting the rest' do
    calls = 0
    allow(AtlasRb::Collection).to receive(:create) do |*, **|
      calls += 1
      raise Faraday::ConnectionFailed, 'boom' if calls == 1

      AtlasRb::Mash.new('id' => "sc-#{calls}")
    end

    result = described_class.call(community_id: 'comm1')

    expect(result.size).to eq(FeaturedContent::GENRES.size - 1)
  end
end
