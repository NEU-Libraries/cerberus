# frozen_string_literal: true

require 'rails_helper'

describe DerivativeCreator do
  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }

  describe 'call' do
    it 'returns the default IIIF URLs as ratios of the source' do
      expect(DerivativeCreator.call(base: base)).to eq(
        small:  "#{base}/full/pct:33/0/default.jpg",
        medium: "#{base}/full/pct:50/0/default.jpg",
        large:  "#{base}/full/pct:75/0/default.jpg"
      )
    end

    it 'treats integer widths as longest-edge fits (!N,N, never upscaling)' do
      widths = { small: 320, medium: 640, large: 1280 }
      expect(DerivativeCreator.call(base: base, widths: widths)).to eq(
        small:  "#{base}/full/!320,320/0/default.jpg",
        medium: "#{base}/full/!640,640/0/default.jpg",
        large:  "#{base}/full/!1280,1280/0/default.jpg"
      )
    end

    it 'treats fractional widths as pct: of source' do
      widths = { small: 0.25, medium: Rational(2, 3), large: 0.9 }
      expect(DerivativeCreator.call(base: base, widths: widths)).to eq(
        small:  "#{base}/full/pct:25/0/default.jpg",
        medium: "#{base}/full/pct:67/0/default.jpg",
        large:  "#{base}/full/pct:90/0/default.jpg"
      )
    end

    it 'prefixes a fractional value above 1.0 with ^' do
      expect(DerivativeCreator.call(base: base, widths: { small: 1.5 }).fetch(:small))
        .to eq("#{base}/full/^pct:150/0/default.jpg")
    end

    it 'mixes value types within one widths hash' do
      widths = { small: 800, medium: 0.5, large: nil }
      expect(DerivativeCreator.call(base: base, widths: widths)).to eq(
        small:  "#{base}/full/!800,800/0/default.jpg",
        medium: "#{base}/full/pct:50/0/default.jpg",
        large:  "#{base}/full/full/0/default.jpg"
      )
    end

    it 'emits the IIIF full size for a nil width' do
      expect(DerivativeCreator.call(base: base, widths: { small: nil }).fetch(:small))
        .to eq("#{base}/full/full/0/default.jpg")
    end

    it 'tolerates string keys (e.g. an ActiveJob-deserialized widths hash)' do
      expect(DerivativeCreator.call(base: base, widths: { 'small' => 100 })).to eq(
        small: "#{base}/full/!100,100/0/default.jpg"
      )
    end

    it 'treats widths: nil as a request for DEFAULT_WIDTHS' do
      expect(DerivativeCreator.call(base: base, widths: nil)).to eq(DerivativeCreator.call(base: base))
    end
  end

  describe 'existing_widths' do
    def assets_for(urls)
      urls.map { |role, uri| AtlasRb::Mash.new(role: "#{role}_image", uri: uri) }
    end

    # The property that matters: whatever #call emits, existing_widths recovers
    # widths that regenerate the SAME URIs. Not "the same width objects" — 0.5
    # comes back as Rational(1, 2), which is the same size. A fourth size shape
    # added to iiif_size without its inverse fails here.
    it 'recovers widths that reproduce the renditions they came from' do
      [
        nil,
        { small: 320, medium: 640, large: 1280 },
        { small: 0.25, medium: Rational(2, 3), large: 0.9 },
        { small: 800, medium: 0.5, large: nil },
        { small: 1.5 }
      ].each do |widths|
        urls = DerivativeCreator.call(base: base, widths: widths)
        recovered = DerivativeCreator.existing_widths(assets_for(urls))

        expect(DerivativeCreator.call(base: base, widths: recovered)).to eq(urls)
      end
    end

    it 'rebuilds against a new base, which is the whole point on a replace' do
      urls = DerivativeCreator.call(base: base)
      recovered = DerivativeCreator.existing_widths(assets_for(urls))

      expect(DerivativeCreator.call(base: 'http://example.com/iiif/3/new.jp2', widths: recovered)).to eq(
        small:  'http://example.com/iiif/3/new.jp2/full/pct:33/0/default.jpg',
        medium: 'http://example.com/iiif/3/new.jp2/full/pct:50/0/default.jpg',
        large:  'http://example.com/iiif/3/new.jp2/full/pct:75/0/default.jpg'
      )
    end

    it 'reads only the rendition tiers, ignoring blobs and the service delegate' do
      assets = [
        AtlasRb::Mash.new(role: 'original_file', noid: 'b-1'),
        AtlasRb::Mash.new(role: 'service_file', uri: base),
        AtlasRb::Mash.new(role: 'small_image', uri: "#{base}/full/pct:33/0/default.jpg")
      ]

      expect(DerivativeCreator.existing_widths(assets)).to eq(small: Rational(33, 100))
    end

    it 'returns nil for a work with no renditions, so the caller can skip' do
      expect(DerivativeCreator.existing_widths([AtlasRb::Mash.new(role: 'original_file')])).to be_nil
      expect(DerivativeCreator.existing_widths([])).to be_nil
    end

    # Defaulting an unreadable tier would rebuild it at `full` — a Small tier
    # serving the full-resolution image, which is a permission leak.
    it 'drops a tier whose size it cannot read, and says so' do
      allow(Rails.logger).to receive(:warn)
      assets = assets_for(small:  "#{base}/full/tricky/0/default.jpg",
                          medium: "#{base}/full/pct:50/0/default.jpg")

      expect(DerivativeCreator.existing_widths(assets)).to eq(medium: Rational(1, 2))
      expect(Rails.logger).to have_received(:warn).with(/unreadable size .* small not rebuilt/)
    end
  end

  describe 'initialize' do
    it 'sets the base and widths' do
      creator = DerivativeCreator.new(base: base, widths: { small: 50 })
      expect(creator.instance_variable_get(:@base)).to eq(base)
      expect(creator.instance_variable_get(:@widths)).to eq(small: 50)
    end

    it 'defaults widths to DEFAULT_WIDTHS' do
      expect(DerivativeCreator.new(base: base).instance_variable_get(:@widths))
        .to eq(DerivativeCreator::DEFAULT_WIDTHS)
    end
  end
end
