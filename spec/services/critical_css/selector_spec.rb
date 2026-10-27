# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CriticalCss::Selector do
  delegate :tokens, to: :described_class

  it 'needs every class, id, tag and attribute name in the selector' do
    expect(tokens('nav#top > ul.menu li a[href^="/x"]')).to contain_exactly('#top', '.menu', '[href', 'nav', 'ul', 'li', 'a')
  end

  it 'ignores pseudo-classes and pseudo-elements' do
    expect(tokens('.btn:hover::before')).to eq ['.btn']
    expect(tokens('.btn-check:checked+.btn')).to contain_exactly('.btn-check', '.btn')
  end

  it 'drops the argument of a functional pseudo-class rather than requiring it' do
    expect(tokens('.a:not(.b)')).to eq ['.a']
    expect(tokens('.row>:is(.x,.y) td:nth-child(2n+1)')).to contain_exactly('.row', 'td')
  end

  it 'needs nothing for :root or the universal selector' do
    expect(tokens(':root')).to eq []
    expect(tokens('*,::after')).to eq []
  end

  it 'unescapes class names the way the page spells them' do
    expect(tokens('.\\31 0')).to eq ['.10']
    expect(tokens('.sm\\:flex')).to eq ['.sm:flex']
  end

  it 'splits a selector list only on top-level commas' do
    expect(described_class.needs(':root,[data-bs-theme=light] .a:is(.b,.c)'))
      .to eq [[], ['[data-bs-theme', '.a']]
  end
end
