# frozen_string_literal: true

require 'rails_helper'

describe DerivativeCreator do
  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }

  describe 'call' do
    it 'returns the sized IIIF URLs keyed by image-derivative role' do
      expect(DerivativeCreator.call(base: base)).to eq(
        'small'  => "#{base}/full/800,/0/default.jpg",
        'medium' => "#{base}/full/1600,/0/default.jpg",
        'large'  => "#{base}/full/full/0/default.jpg"
      )
    end
  end

  describe 'initialize' do
    it 'sets the base' do
      expect(DerivativeCreator.new(base: base).instance_variable_get(:@base)).to eq(base)
    end
  end
end
