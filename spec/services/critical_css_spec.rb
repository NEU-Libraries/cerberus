# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CriticalCss, :critical_css do
  def select(css, html)
    described_class.new(CriticalCss::Stylesheet.parse(css), CriticalCss::Markup.tokens(html)).css
  end

  describe '#css' do
    let(:css) do
      ':root{--x:1}.used{a:1}.unused{b:2}@media (min-width:1px){.used{c:3}.other{d:4}.used.more{e:5}}' \
        '@font-face{font-family:f}@keyframes pulse{to{o:1}}@keyframes idle{to{o:0}}.anim{animation:pulse 1s}'
    end

    it 'keeps the rules the page can match, in their original order' do
      expect(select(css, '<p class="used">')).to eq ':root{--x:1}.used{a:1}@media (min-width:1px){.used{c:3}}' \
                                                    '@font-face{font-family:f}'
    end

    it 'puts consecutive rules under one shared @media wrapper' do
      expect(select(css, '<p class="used more">')).to include '@media (min-width:1px){.used{c:3}.used.more{e:5}}'
    end

    it 'keeps an @keyframes only when a kept rule names it' do
      kept = select(css, '<p class="anim">')

      expect(kept).to include('@keyframes pulse{to{o:1}}')
      expect(kept).not_to include('idle')
    end
  end

  describe '.for' do
    it 'selects from the compiled layout stylesheets, Font Awesome icons included' do
      css = described_class.for('<html><body><a class="btn btn-primary"><i class="fa-solid fa-user"></i></a></body></html>')

      expect(css).to include('.btn{', '.btn-primary{', '.fa-user', '@font-face')
      expect(css).not_to include('.offcanvas{', '.fa-twitter')
    end

    it 'gives nil when a layout stylesheet is missing, so the caller keeps the blocking links' do
      allow(Rails.application.assets.load_path).to receive(:find).and_call_original
      allow(Rails.application.assets.load_path).to receive(:find).with('css/all.min.css').and_return(nil)

      expect(described_class.for('<p>')).to be_nil
    end
  end
end
