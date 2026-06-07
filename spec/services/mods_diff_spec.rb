# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MODSDiff do
  def mods(title)
    <<~XML
      <mods xmlns="http://www.loc.gov/mods/v3">
        <titleInfo><title>#{title}</title></titleInfo>
      </mods>
    XML
  end

  it 'returns a Diffy::Diff' do
    expect(described_class.call(from_xml: mods('A'), to_xml: mods('B'))).to be_a(Diffy::Diff)
  end

  it 'surfaces the changed content in the diff' do
    diff = described_class.call(from_xml: mods('Garden Party'), to_xml: mods('Garden Party (2022)'))
    expect(diff.to_s(:text)).to include('Garden Party (2022)')
  end

  it 'canonicalises away pure formatting differences (no content +/- lines)' do
    compact = '<mods xmlns="http://www.loc.gov/mods/v3"><titleInfo><title>X</title></titleInfo></mods>'
    diff    = described_class.call(from_xml: compact, to_xml: mods('X'))
    changed = diff.to_s(:text).each_line.select { |line| line.start_with?('+', '-') }
    expect(changed).to be_empty
  end

  it 'falls back to the raw string for unparseable XML instead of raising' do
    expect { described_class.call(from_xml: 'not<xml', to_xml: mods('X')) }.not_to raise_error
  end
end
