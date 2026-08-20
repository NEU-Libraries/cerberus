# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SetWorkEnumerator do
  # One page of the contents endpoint, in the shape atlas_rb returns.
  def page(noids, pages:, page: 1)
    AtlasRb::Mash.new(
      'contents'   => noids.map { |noid| { 'noid' => noid, 'klass' => 'Work', 'title' => noid } },
      'pagination' => { 'total' => noids.size, 'page' => page, 'per_page' => 100, 'pages' => pages }
    )
  end

  def run(nuid: '000000010')
    described_class.new(set_noid: 'set-1', nuid: nuid).call
  end

  it 'returns the noids of a single page' do
    allow(AtlasRb::Compilation).to receive(:contents).and_return(page(%w[w1 w2 w3], pages: 1))

    expect(run.noids).to eq(%w[w1 w2 w3])
  end

  it 'walks every page' do
    allow(AtlasRb::Compilation).to receive(:contents)
      .with('set-1', hash_including(page: 1)).and_return(page(%w[w1 w2], pages: 2, page: 1))
    allow(AtlasRb::Compilation).to receive(:contents)
      .with('set-1', hash_including(page: 2)).and_return(page(%w[w3 w4], pages: 2, page: 2))

    expect(run.noids).to eq(%w[w1 w2 w3 w4])
  end

  it 'stops on the last page rather than paying an empty request to find the end' do
    allow(AtlasRb::Compilation).to receive(:contents).and_return(page(%w[w1], pages: 1))

    run

    expect(AtlasRb::Compilation).to have_received(:contents).once
  end

  it 'passes the acting nuid through, so the walk is scoped to that operator' do
    allow(AtlasRb::Compilation).to receive(:contents).and_return(page(%w[w1], pages: 1))

    run(nuid: '000000004')

    expect(AtlasRb::Compilation).to have_received(:contents).with('set-1', hash_including(nuid: '000000004'))
  end

  it 'reports nothing to do for an empty set' do
    allow(AtlasRb::Compilation).to receive(:contents).and_return(page([], pages: 0))

    result = run
    expect(result.noids).to be_empty
    expect(result.truncated).to be false
  end

  it 'de-duplicates, so a work reached twice by one recipe is written once' do
    allow(AtlasRb::Compilation).to receive(:contents).and_return(page(%w[w1 w1 w2], pages: 1))

    expect(run.noids).to eq(%w[w1 w2])
  end

  describe 'the cap' do
    before { stub_const("#{described_class}::MAX_WORKS", 3) }

    it 'stops at MAX_WORKS and says it was truncated' do
      allow(AtlasRb::Compilation).to receive(:contents).and_return(page(%w[w1 w2 w3 w4 w5], pages: 1))

      result = run
      expect(result.noids).to eq(%w[w1 w2 w3])
      expect(result.truncated).to be true
    end

    it 'does not claim truncation when the set lands exactly on the cap' do
      allow(AtlasRb::Compilation).to receive(:contents).and_return(page(%w[w1 w2 w3], pages: 1))

      expect(run.truncated).to be false
    end

    # The page-boundary case: the cap is reached exactly as a page ends, with
    # more pages behind it. Testing only for overflow would call this a clean
    # run and leave the rest of the set silently untouched.
    it 'reports truncation when it lands on the cap with pages still to come' do
      allow(AtlasRb::Compilation).to receive(:contents)
        .with('set-1', hash_including(page: 1)).and_return(page(%w[w1 w2 w3], pages: 4, page: 1))

      result = run
      expect(result.noids).to eq(%w[w1 w2 w3])
      expect(result.truncated).to be true
    end
  end
end
