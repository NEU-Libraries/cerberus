# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CriticalCss::Stylesheet do
  delegate :parse, to: :described_class

  it 'splits top-level rules and keeps each one verbatim' do
    rules = parse('.a{color:red}.b,.c{margin:0}')

    expect(rules.map(&:css)).to eq ['.a{color:red}', '.b,.c{margin:0}']
    expect(rules.map(&:needs)).to eq [[['.a']], [['.b'], ['.c']]]
  end

  it 'tags each rule inside a grouping rule with its chain of at-rules' do
    rules = parse('@media (min-width: 768px){@supports (display:grid){.g{display:grid}}.m{x:1}}.top{y:2}')

    expect(rules.map { |rule| [rule.css, rule.context] }).to eq [
      ['.g{display:grid}', ['@media (min-width: 768px)', '@supports (display:grid)']],
      ['.m{x:1}', ['@media (min-width: 768px)']],
      ['.top{y:2}', []]
    ]
  end

  it 'keeps @font-face for every page and names each @keyframes' do
    rules = parse('@font-face{font-family:x}@keyframes spin{0%{a:b}to{a:c}}@-webkit-keyframes spin{to{a:c}}')

    expect(rules.first).to have_attributes(needs: nil)
    expect(rules.drop(1)).to all(be_a(CriticalCss::Stylesheet::Keyframes).and(have_attributes(name: 'spin')))
    expect(rules[1].css).to eq '@keyframes spin{0%{a:b}to{a:c}}'
  end

  it 'is not thrown by braces, slashes or comments inside values and strings' do
    css = '/*! banner {x} */.q::after{content:"}{"}.f{font:1rem/1.5 x;background:url("a/*b*/c.svg")}.n{a:b}'

    expect(parse(css).map(&:css)).to eq ['.q::after{content:"}{"}',
                                         '.f{font:1rem/1.5 x;background:url("a/*b*/c.svg")}', '.n{a:b}']
  end

  it 'drops a leading byte-order mark and keeps multibyte text intact' do
    rules = parse("\uFEFF.a::before{content:\"—\"}.b{c:d}")

    expect(rules.map(&:css)).to eq ['.a::before{content:"—"}', '.b{c:d}']
    expect(rules.first.css.encoding).to eq Encoding::UTF_8
  end
end
