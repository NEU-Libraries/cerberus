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

  describe '#av_poster_src' do
    it 'keeps the Work\'s own poster' do
      expect(helper.av_poster_src('https://iiif/p.jpg')).to eq('https://iiif/p.jpg')
    end

    it 'falls back to the placeholder mark' do
      expect(helper.av_poster_src(nil)).to match(/av-placeholder/)
      expect(helper.av_poster_src('')).to match(/av-placeholder/)
    end
  end

  describe '#preview_image_attributes' do
    let(:frame) { ThumbnailsHelper::PREVIEW_FRAME }
    let(:placeholder) { Base64.strict_encode64('jpeg bytes') }

    # The SVG the placeholder sits in, decoded from the style's data URI.
    def svg(style) = Base64.strict_decode64(style[%r{svg\+xml;base64,([A-Za-z0-9+/=]+)}, 1])

    it 'renders the bare frame when the Work has no size' do
      expect(helper.preview_image_attributes(nil, nil, placeholder)).to eq(style: frame)
    end

    # Width and height travel together; half a size cannot reserve a frame.
    it 'renders the bare frame when either dimension is missing' do
      expect(helper.preview_image_attributes(500, nil, nil)).to eq(style: frame)
      expect(helper.preview_image_attributes(0, 333, nil)).to eq(style: frame)
    end

    it 'reserves the frame and scales it in proportion' do
      expect(helper.preview_image_attributes(500, 333, nil)).to eq(width: 500, height: 333,
                                                                   style: "#{frame} height: auto;")
    end

    it 'paints the blurred placeholder inside the padding' do
      style = helper.preview_image_attributes(500, 333, placeholder)[:style]

      expect(style).to include('background-size: cover', 'background-clip: content-box',
                               'background-origin: content-box')
      expect(svg(style)).to include("viewBox='0 0 500 333'", "stdDeviation='18'",
                                    "href='data:image/jpeg;base64,#{placeholder}'")
    end

    it 'keeps the viewBox in the preview proportion' do
      style = helper.preview_image_attributes(300, 600, placeholder)[:style]

      expect(svg(style)).to include("viewBox='0 0 500 1000'")
    end

    # The value lands inside the SVG markup, so anything but base64 is dropped.
    it 'ignores a placeholder that is not base64' do
      expect(helper.preview_image_attributes(500, 333, "x' onload='y")[:style]).to eq("#{frame} height: auto;")
    end
  end

  describe '#thumbnail_with_fallback' do
    let(:html) do
      Capybara.string(helper.thumbnail_with_fallback('https://iiif.example/t.jpg', helper.tag.i(class: 'fa-image'),
                                                     fallback_class: 'thumbnail-fallback', alt: '', loading: 'lazy'))
    end

    it 'renders the image with its own error handler' do
      img = html.find('img')

      expect(img[:onerror]).to eq(ThumbnailsHelper::THUMBNAIL_ONERROR)
      expect(img[:alt]).to eq('')
      expect(img[:loading]).to eq('lazy')
    end

    # The handler reveals the element straight after the image, so the order matters.
    it 'renders the fallback hidden, directly after the image' do
      expect(html).to have_css('img + span.thumbnail-fallback.d-none > i.fa-image', visible: :all)
    end
  end
end
