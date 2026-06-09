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

  describe 'title parts (Advanced form)' do
    it 'edits an existing part in place and adds a missing one, preserving the title' do
      d = doc(described_class.call(xml: xml, part_name: 'Updated Part', subtitle: 'A Subtitle'))
      ti = d.at_xpath("/mods:mods/mods:titleInfo[@usage='primary']", ns)
      expect(ti.at_xpath('mods:title', ns).text).to eq("What's New")
      expect(ti.at_xpath('mods:partName', ns).text).to eq('Updated Part')
      expect(ti.at_xpath('mods:subTitle', ns).text).to eq('A Subtitle')
    end

    it 'removes a part when cleared (blank), leaving the others' do
      d = doc(described_class.call(xml: xml, part_number: ''))
      ti = d.at_xpath("/mods:mods/mods:titleInfo[@usage='primary']", ns)
      expect(ti.at_xpath('mods:partNumber', ns)).to be_nil
      expect(ti.at_xpath('mods:partName', ns).text).to eq('How We Respond to Disaster')
    end

    it 'leaves title parts untouched when nil' do
      out = described_class.call(xml: xml, subtitle: nil, part_name: nil, part_number: nil, non_sort: nil)
      expect(described_class.unchanged?(xml, out)).to be(true)
    end
  end

  describe 'creators (Advanced form)' do
    # the fixture's 3 names all carry valueURI (authority-controlled / preserved)
    def authority_names(parsed)
      parsed.xpath('/mods:mods/mods:name[@valueURI]', ns)
    end

    it 'adds a plain personal creator (given/family + text Creator role), preserving authority names' do
      d = doc(described_class.call(xml: xml, personal_creators: [{ given: 'Jenny', family: 'Smith' }]))
      expect(d.xpath('/mods:mods/mods:name', ns).size).to eq(4)
      added = d.xpath("/mods:mods/mods:name[@type='personal']", ns).find { |n| n['valueURI'].nil? }
      expect(added.at_xpath("mods:namePart[@type='given']", ns).text).to eq('Jenny')
      expect(added.at_xpath("mods:namePart[@type='family']", ns).text).to eq('Smith')
      expect(added.at_xpath("mods:role/mods:roleTerm[@type='text']", ns).text).to eq('Creator')
      expect(authority_names(d).size).to eq(3)
    end

    it 'adds a plain corporate creator, preserving authority names' do
      d = doc(described_class.call(xml: xml, corporate_creators: ['Acme Corp']))
      added = d.xpath("/mods:mods/mods:name[@type='corporate']", ns).find { |n| n['valueURI'].nil? }
      expect(added.at_xpath('mods:namePart', ns).text).to eq('Acme Corp')
      expect(authority_names(d).size).to eq(3)
    end

    it 'leaves names untouched when creators are nil' do
      out = described_class.call(xml: xml, personal_creators: nil, corporate_creators: nil)
      expect(described_class.unchanged?(xml, out)).to be(true)
    end

    it 're-merging the same editable creator is a no-op (no version churn)' do
      once = described_class.call(xml: xml, personal_creators: [{ given: 'Jenny', family: 'Smith' }])
      twice = described_class.call(xml: once, personal_creators: [{ given: 'Jenny', family: 'Smith' }])
      expect(described_class.unchanged?(once, twice)).to be(true)
    end

    it 'clears editable creators ([]), leaving authority names intact' do
      with = described_class.call(xml: xml, personal_creators: [{ given: 'Jenny', family: 'Smith' }])
      d = doc(described_class.call(xml: with, personal_creators: []))
      expect(d.xpath('/mods:mods/mods:name', ns).size).to eq(3)
      expect(authority_names(d).size).to eq(3)
    end
  end
end
