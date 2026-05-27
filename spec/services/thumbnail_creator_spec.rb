# frozen_string_literal: true

require 'rails_helper'

describe ThumbnailCreator do
  let(:base) { 'http://example.com/iiif/3/123456789.jp2' }

  describe 'call' do
    it 'returns the sized IIIF URLs keyed by thumbnail-family role' do
      expect(ThumbnailCreator.call(base: base)).to eq(
        thumbnail:    "#{base}/full/!85,85/0/default.jpg",
        thumbnail_2x: "#{base}/full/!170,170/0/default.jpg",
        preview:      "#{base}/full/500,/0/default.jpg"
      )
    end
  end

  describe 'initialize' do
    it 'sets the base' do
      expect(ThumbnailCreator.new(base: base).instance_variable_get(:@base)).to eq(base)
    end
  end
end
