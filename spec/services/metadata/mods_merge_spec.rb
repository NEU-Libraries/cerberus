# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Metadata::MODSMerge do
  let(:ns) { { 'mods' => 'http://www.loc.gov/mods/v3' } }
  let(:xml) { Rails.root.join('spec/fixtures/files/work-mods.xml').read }

  def doc(xml_str)
    Nokogiri::XML(xml_str)
  end

  def bare_topics(parsed)
    parsed.xpath('/mods:mods/mods:subject', ns)
          .select { |s| s.attributes.empty? && s.xpath('mods:topic', ns).any? }
          .flat_map { |s| s.xpath('mods:topic', ns).map(&:text) }
  end

  describe 'title' do
    it 'edits the primary <title> and preserves partName / partNumber' do
      d = doc(described_class.call(xml: xml, title: 'New Title'))
      ti = d.at_xpath("/mods:mods/mods:titleInfo[@usage='primary']", ns)
      expect(ti.at_xpath('mods:title', ns).text).to eq('New Title')
      expect(ti.at_xpath('mods:partName', ns).text).to eq('How We Respond to Disaster')
      expect(ti.at_xpath('mods:partNumber', ns).text).to eq('Episode 1')
    end

    it 'never touches a title nested in a relatedItem' do
      d = doc(described_class.call(xml: xml, title: 'New Title'))
      nested = d.at_xpath('/mods:mods/mods:relatedItem/mods:titleInfo/mods:title', ns)
      expect(nested.text).to eq("What's New Podcast")
    end

    it 'is a no-op for an unchanged title' do
      out = described_class.call(xml: xml, title: "What's New")
      expect(described_class.unchanged?(xml, out)).to be(true)
    end

    it 'is a no-op for a whitespace-only title change (no version churn)' do
      out = described_class.call(xml: xml, title: "What's New ")
      expect(described_class.unchanged?(xml, out)).to be(true)
    end
  end

  describe 'abstract' do
    it 'edits the first <abstract> in place' do
      d = doc(described_class.call(xml: xml, abstract: 'New abstract.'))
      expect(d.at_xpath('/mods:mods/mods:abstract', ns).text).to eq('New abstract.')
    end
  end

  describe 'keywords' do
    it 'appends free-text keyword subjects while preserving curated lcsh + name subjects' do
      d = doc(described_class.call(xml: xml, keywords: %w[climate resilience]))
      expect(d.xpath("/mods:mods/mods:subject[@authority='lcsh']", ns).size).to eq(5)
      expect(d.at_xpath('/mods:mods/mods:subject/mods:name', ns)).not_to be_nil
      expect(bare_topics(d)).to contain_exactly('climate', 'resilience')
    end

    it 'removes keyword subjects when cleared, leaving curated subjects intact' do
      with_kw = described_class.call(xml: xml, keywords: ['climate'])
      d = doc(described_class.call(xml: with_kw, keywords: []))
      expect(d.xpath("/mods:mods/mods:subject[@authority='lcsh']", ns).size).to eq(5)
      expect(bare_topics(d)).to be_empty
    end

    it 'leaves subjects untouched when keywords is nil' do
      out = described_class.call(xml: xml, keywords: nil)
      expect(described_class.unchanged?(xml, out)).to be(true)
    end
  end

  it 'preserves unrelated nodes and other namespaces (names, genre, extensions)' do
    d = doc(described_class.call(xml: xml, title: 'X', abstract: 'Y', keywords: ['z']))
    expect(d.xpath('/mods:mods/mods:name', ns).size).to eq(3)
    expect(d.at_xpath('/mods:mods/mods:genre', ns).text).to eq('podcasts')
    expect(d.at_xpath('//niec:niec', 'niec' => 'http://repository.neu.edu/schema/niec')).not_to be_nil
  end
end
