# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'works/_image', type: :view do
  let(:src) { 'https://iiif.example/iiif/3/open-aaa.tif/full/max/0/default.jpg' }

  def preview_img(**locals)
    render partial: 'works/image', locals: { src: src, alt: 'Preview of A Work', **locals }
    Capybara.string(rendered).find('img')
  end

  it 'renders the frame without a size, as before the Work carried one' do
    img = preview_img

    expect(img[:width]).to be_nil
    expect(img[:height]).to be_nil
    expect(img[:style]).not_to include('background-image')
  end

  it 'reserves the frame and paints the placeholder when the Work carries them' do
    img = preview_img(width: 500, height: 333, placeholder: Base64.strict_encode64('jpeg bytes'))

    expect(img[:width]).to eq('500')
    expect(img[:height]).to eq('333')
    expect(img[:style]).to include('background-image: url(data:image/svg+xml;base64,')
  end

  # The placeholder is CSS decoration; the alt text is the only thing announced.
  it 'keeps the alt text and the eager, high-priority load' do
    img = preview_img(width: 500, height: 333)

    expect(img[:alt]).to eq('Preview of A Work')
    expect(img[:fetchpriority]).to eq('high')
    expect(img[:src]).to eq(src)
  end

  # The state ships as "idle" so a page without JS never blurs, and as an
  # attribute so the critical CSS selector scan keeps its rules.
  it 'renders the blur-up frame idle, with its script, around the image' do
    render partial: 'works/image', locals: { src: src, alt: 'Preview of A Work', width: 500, height: 333 }
    page = Capybara.string(rendered)

    expect(page).to have_css('.preview-blur-up[data-blur-up="idle"] > img[fetchpriority="high"]')
    expect(page).to have_css('.preview-blur-up > script', visible: :all)
  end

  # The icon a failed load shows is decoration; the heading names the Work.
  it 'carries the failed-load icon, hidden from screen readers' do
    render partial: 'works/image', locals: { src: src, alt: 'Preview of A Work', width: 500, height: 333 }

    expect(Capybara.string(rendered)).to have_css('.preview-blur-up__icon[aria-hidden="true"] .fa-image', visible: :all)
  end
end
