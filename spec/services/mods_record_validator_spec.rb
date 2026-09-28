# frozen_string_literal: true

require 'rails_helper'

describe MODSRecordValidator do
  let(:schema_uri) { 'http://www.loc.gov/standards/mods/v3/mods-3-7.xsd' }

  def mods(body)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xsi:schemaLocation="http://www.loc.gov/mods/v3 #{schema_uri}">
        #{body}
      </mods:mods>
    XML
  end

  let(:title)   { '<mods:titleInfo><mods:title>Test</mods:title></mods:titleInfo>' }
  let(:keyword) { '<mods:subject><mods:topic>Boston</mods:topic></mods:subject>' }

  before do
    allow(Kataba).to receive(:fetch_schema).with(schema_uri)
                                           .and_return(instance_double(Nokogiri::XML::Schema, validate: []))
  end

  it 'accepts a record with a title and a keyword' do
    expect(described_class.call(xml: mods(title + keyword), keywords: true)).to eq([])
  end

  it 'refuses a record with no title' do
    expect(described_class.call(xml: mods(keyword), keywords: true)).to eq([described_class::NO_TITLE])
  end

  it 'refuses a title that is only whitespace' do
    blank = '<mods:titleInfo><mods:title>  </mods:title></mods:titleInfo>'
    expect(described_class.call(xml: mods(blank + keyword), keywords: true)).to eq([described_class::NO_TITLE])
  end

  it 'refuses a record with no keywords when keywords are required' do
    expect(described_class.call(xml: mods(title), keywords: true)).to eq([described_class::NO_KEYWORDS])
  end

  it 'refuses an empty topic' do
    empty = '<mods:subject><mods:topic/></mods:subject>'
    expect(described_class.call(xml: mods(title + empty), keywords: true)).to eq([described_class::NO_KEYWORDS])
  end

  it 'counts an authority subject as a keyword' do
    curated = '<mods:subject authority="lcsh"><mods:topic>Boston</mods:topic></mods:subject>'
    expect(described_class.call(xml: mods(title + curated), keywords: true)).to eq([])
  end

  it 'reports both missing fields at once' do
    expect(described_class.call(xml: mods(''), keywords: true))
      .to eq([described_class::NO_TITLE, described_class::NO_KEYWORDS])
  end

  it 'skips the keyword rule where keywords are not required' do
    expect(described_class.call(xml: mods(title), keywords: false)).to eq([])
  end

  it 'reports the schema floor first, without the field rules' do
    errors = described_class.call(xml: '<mods:mods><titleInfo>unclosed', keywords: true)
    expect(errors.size).to eq(1)
    expect(errors.first).to be_a(Nokogiri::XML::SyntaxError)
  end
end
