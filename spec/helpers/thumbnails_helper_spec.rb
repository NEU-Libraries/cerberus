# frozen_string_literal: true

require 'rails_helper'

describe ThumbnailsHelper do
  # image_tag resolves a relative src through Propshaft, which RAISES on a miss
  # rather than emitting a broken image. Every caller renders whatever Solr
  # holds, so this guard is what stops one malformed value 500ing a whole page.
  describe '#renderable_thumbnail' do
    it 'passes an absolute URL through' do
      url = 'http://localhost:8182/iiif/3/open-abc.jp2/full/!85,85/0/default.jpg'
      expect(helper.renderable_thumbnail(url)).to eq(url)
    end

    it 'passes an https URL through' do
      expect(helper.renderable_thumbnail('https://example.com/t.jpg')).to eq('https://example.com/t.jpg')
    end

    it 'passes a protocol-relative URL through' do
      expect(helper.renderable_thumbnail('//example.com/t.jpg')).to eq('//example.com/t.jpg')
    end

    it 'refuses a relative value, which is what reaches Propshaft' do
      expect(helper.renderable_thumbnail('t2')).to be_nil
      expect(helper.renderable_thumbnail('images/t.jpg')).to be_nil
    end

    it 'refuses a blank or missing value' do
      expect(helper.renderable_thumbnail(nil)).to be_nil
      expect(helper.renderable_thumbnail('')).to be_nil
    end
  end
end
