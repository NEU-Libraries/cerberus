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

    it 'treats integer widths as fixed pixel widths with the ^ prefix' do
      widths = { small: 320, medium: 640, large: 1280 }
      expect(DerivativeCreator.call(base: base, widths: widths)).to eq(
        small:  "#{base}/full/^320,/0/default.jpg",
        medium: "#{base}/full/^640,/0/default.jpg",
        large:  "#{base}/full/^1280,/0/default.jpg"
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
        small:  "#{base}/full/^800,/0/default.jpg",
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
        small: "#{base}/full/^100,/0/default.jpg"
      )
    end

    it 'treats widths: nil as a request for DEFAULT_WIDTHS' do
      expect(DerivativeCreator.call(base: base, widths: nil)).to eq(DerivativeCreator.call(base: base))
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
