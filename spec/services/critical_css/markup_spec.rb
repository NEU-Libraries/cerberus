# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CriticalCss::Markup do
  delegate :tokens, to: :described_class

  it 'collects tag names, classes, ids and attribute names' do
    expect(tokens('<DIV id="main" class=" card  p-3 " data-turbo="false"><a href=x>y</a></DIV>'))
      .to include('div', 'a', '#main', '.card', '.p-3', '[id', '[class', '[data-turbo', '[href')
  end

  it 'reads every attribute of a tag whose values contain >' do
    expect(tokens('<button data-action="click->sets#add" class="btn">'))
      .to include('[data-action', '.btn')
  end

  it 'counts markup inside a <template>, which Stimulus clones into the page' do
    expect(tokens('<template><li class="chip">x</li></template>')).to include('li', '.chip')
  end

  it 'decodes entities in class names' do
    expect(tokens('<i class="a&amp;b">')).to include('.a&b')
  end
end
