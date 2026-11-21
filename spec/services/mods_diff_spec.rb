# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MODSDiff do
  def mods(title, extra = '')
    <<~XML
      <mods xmlns="http://www.loc.gov/mods/v3">
        <titleInfo><title>#{title}</title></titleInfo>#{extra}
      </mods>
    XML
  end

  def diff(from, to)
    described_class.call(from_xml: from, to_xml: to)
  end

  def changed(rows)
    rows.reject { |row| row.kind == :same }
  end

  def marked(row)
    row.segments.select(&:changed).map(&:text)
  end

  it 'numbers unchanged lines on both sides' do
    rows = diff(mods('A'), mods('A'))
    expect(rows.map(&:kind).uniq).to eq([:same])
    expect(rows.map { |row| [row.old_number, row.new_number] }.first(2)).to eq([[1, 1], [2, 2]])
  end

  it 'marks only the changed words of an edited line' do
    rows = changed(diff(mods('Garden Party'), mods('Garden Party (2022)')))
    expect(rows.map(&:kind)).to eq(%i[del ins])
    expect(marked(rows.first)).to be_empty
    expect(marked(rows.last)).to eq([' (2022)'])
  end

  it 'marks a changed number as a whole word, not a changed digit' do
    del, ins = changed(diff(mods('Survey 1998'), mods('Survey 1999')))
    expect(marked(del)).to eq(['1998'])
    expect(marked(ins)).to eq(['1999'])
  end

  it 'joins neighbouring changed words into one mark' do
    _del, ins = changed(diff(mods('Survey'), mods('Survey of the harbor')))
    expect(marked(ins)).to eq([' of the harbor'])
  end

  it 'prints every removal in a block before every addition' do
    from = mods('A', "\n  <genre>report</genre>\n  <note>first</note>")
    to = mods('A', "\n  <genre>survey</genre>\n  <note>second</note>")
    expect(changed(diff(from, to)).map(&:kind)).to eq(%i[del del ins ins])
  end

  it 'leaves a wholly removed or added line unmarked' do
    rows = changed(diff(mods('A'), mods('A', "\n  <genre>report</genre>")))
    expect(rows.map(&:kind)).to eq([:ins])
    expect(marked(rows.first)).to be_empty
    expect(rows.first.new_number).to eq(6) # after the declaration and the pretty-printed titleInfo
  end

  it 'leaves an edit unmarked when the two lines share too little' do
    to = "<mods xmlns=\"http://www.loc.gov/mods/v3\">\n  <titleInfo><title/></titleInfo>\n</mods>"
    rows = changed(diff(mods('Salt Marsh Boundary Survey'), to))
    expect(rows.flat_map { |row| marked(row) }).to be_empty
  end

  it 'pairs an edit with the removed line most like it, not the one in its position' do
    removed = (1..5).map { |n| "\n  <note>removed note #{n}</note>" }.join
    from = mods('A', "#{removed}\n  <identifier type=\"hdl\">http://hdl.example/1</identifier>")
    to = mods('A', "\n  <identifier type=\"hdl\">http://hdl.example/2</identifier>")
    rows = changed(diff(from, to))
    expect(marked(rows.find { |row| row.kind == :ins })).to eq(['2'])
    expect(rows.select { |row| marked(row).any? }.map(&:kind)).to eq(%i[del ins])
  end

  it 'does not pair two different elements because their punctuation matches' do
    from = mods('A', "\n  <nonSort/>")
    to = mods('A', "\n  <title/>")
    expect(changed(diff(from, to)).flat_map { |row| marked(row) }).to be_empty
  end

  it 'pairs an emptied element with its old self, not a structurally similar neighbour' do
    from = mods('A', "\n  <name type=\"corporate\" usage=\"primary\"/>" \
                     "\n  <identifier type=\"hdl\" displayLabel=\"Permanent URL\">http://hdl.example/1</identifier>")
    to = mods('A', "\n  <identifier type=\"hdl\" displayLabel=\"Permanent URL\"/>")
    rows = changed(diff(from, to))
    paired = rows.find { |row| row.kind == :del && marked(row).any? }
    expect(paired.segments.map(&:text).join).to include('<identifier')
  end

  it 'skips word marks when a block is too large to pair' do
    from = mods('A', (1..30).map { |n| "\n  <note>old note #{n}</note>" }.join)
    to = mods('A', (1..30).map { |n| "\n  <note>new note #{n}</note>" }.join)
    expect(changed(diff(from, to)).flat_map { |row| marked(row) }).to be_empty
  end

  it 'canonicalises away pure formatting differences' do
    compact = '<mods xmlns="http://www.loc.gov/mods/v3"><titleInfo><title>X</title></titleInfo></mods>'
    expect(changed(diff(compact, mods('X')))).to be_empty
  end

  it 'falls back to the raw string for unparseable XML instead of raising' do
    expect(changed(diff('not<xml', mods('X')))).not_to be_empty
  end
end
