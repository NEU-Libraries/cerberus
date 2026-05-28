# frozen_string_literal: true

require 'rails_helper'

describe Iptc::Extractor do
  let(:fixtures) { Rails.root.join('spec/fixtures/files') }

  describe '.call against fixture JPEGs' do
    context 'with a clean IPTC JPEG (marcom.jpeg)' do
      subject(:result) { described_class.call(path: fixtures.join('marcom.jpeg').to_s) }

      it 'returns a Result' do
        expect(result).to be_a(Iptc::Extractor::Result)
      end

      it 'parses the Headline tag as a non-empty string' do
        expect(result.tags[:Headline]).to be_a(String).and(be_present)
      end

      it 'parses the Keywords tag as a non-empty array of strings' do
        expect(result.tags[:Keywords]).to be_a(Array).and(be_present)
        expect(result.tags[:Keywords]).to all(be_a(String))
      end

      it 'exposes image dimensions as positive integers' do
        expect(result.width).to be_a(Integer).and(be > 0)
        expect(result.height).to be_a(Integer).and(be > 0)
      end

      it 'computes longest_side from width/height' do
        expect(result.longest_side).to eq([result.width, result.height].max)
      end
    end

    context 'with marcom_no_title.jpg' do
      subject(:result) { described_class.call(path: fixtures.join('marcom_no_title.jpg').to_s) }

      it 'omits the Headline tag entirely (skipped as blank)' do
        expect(result.tags).not_to include(:Headline)
      end
    end

    context 'with marcom_no_keyword.jpg' do
      subject(:result) { described_class.call(path: fixtures.join('marcom_no_keyword.jpg').to_s) }

      it 'omits the Keywords tag entirely (skipped as blank)' do
        expect(result.tags).not_to include(:Keywords)
      end
    end
  end

  describe 'type coercion (with stubbed MiniExiftool)' do
    let(:photo) { instance_double(MiniExiftool) }
    let(:path) { '/tmp/fake.jpg' }

    before do
      allow(MiniExiftool).to receive(:new).with(path, hash_including(iptc_encoding: 'UTF8')).and_return(photo)
      allow(photo).to receive(:imagewidth).and_return(100)
      allow(photo).to receive(:imageheight).and_return(200)
    end

    def stub_tags(tags_hash)
      string_keys = tags_hash.transform_keys(&:to_s)
      allow(photo).to receive(:tags).and_return(string_keys.keys)
      string_keys.each { |k, v| allow(photo).to receive(:[]).with(k).and_return(v) }
    end

    it 'keeps String values as-is' do
      stub_tags(Headline: 'A nice title')
      expect(described_class.call(path: path).tags).to eq(Headline: 'A nice title')
    end

    it 'keeps Time values as-is' do
      t = Time.utc(2026, 5, 28, 12, 0)
      stub_tags(DateTimeOriginal: t)
      expect(described_class.call(path: path).tags).to eq(DateTimeOriginal: t)
    end

    it 'stringifies Integer values' do
      stub_tags(SomeIntTag: 1920)
      expect(described_class.call(path: path).tags).to eq(SomeIntTag: '1920')
    end

    it 'stringifies Float values' do
      stub_tags(GPSAltitude: 12.5)
      expect(described_class.call(path: path).tags).to eq(GPSAltitude: '12.5')
    end

    it 'stringifies booleans' do
      stub_tags(Flash: true)
      expect(described_class.call(path: path).tags).to eq(Flash: 'true')
    end

    it 'maps Array elements to strings and removes blank entries' do
      stub_tags(Keywords: ['athletics', '', 'campus', nil])
      expect(described_class.call(path: path).tags).to eq(Keywords: %w[athletics campus])
    end

    it 'skips nil values' do
      stub_tags(Headline: nil, Keywords: ['x'])
      expect(described_class.call(path: path).tags).to eq(Keywords: ['x'])
    end

    it 'skips empty-string values' do
      stub_tags(Headline: '', Keywords: ['x'])
      expect(described_class.call(path: path).tags).to eq(Keywords: ['x'])
    end

    it 'skips empty arrays' do
      stub_tags(Keywords: [], Headline: 'OK')
      expect(described_class.call(path: path).tags).to eq(Headline: 'OK')
    end

    it 'raises UnsupportedIptcType on unexpected value classes' do
      stub_tags(WeirdTag: Object.new)
      expect { described_class.call(path: path) }
        .to raise_error(Iptc::Extractor::UnsupportedIptcType, /WeirdTag.*Object/)
    end
  end

  describe Iptc::Extractor::Result do
    it 'returns the longer of width/height for longest_side' do
      expect(described_class.new(tags: {}, width: 1000, height: 2000).longest_side).to eq(2000)
      expect(described_class.new(tags: {}, width: 3000, height: 2000).longest_side).to eq(3000)
    end

    it 'tolerates nil width/height (returns 0)' do
      expect(described_class.new(tags: {}, width: nil, height: nil).longest_side).to eq(0)
    end
  end
end
