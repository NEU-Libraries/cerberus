# frozen_string_literal: true

require 'rails_helper'

describe Iptc::MODSBuilder do
  let(:minimum_iptc) { { Headline: 'A photo', Keywords: ['athletics'] } }

  def doc(iptc)
    Nokogiri::XML(described_class.call(iptc: iptc).xml).remove_namespaces!
  end

  describe '.call with minimum required fields' do
    let(:result) { described_class.call(iptc: minimum_iptc) }

    it 'returns an XML string' do
      expect(result.xml).to be_a(String).and(include('<?xml'))
    end

    it 'returns no warnings' do
      expect(result.warnings).to eq([])
    end

    it 'emits the title from Headline' do
      expect(doc(minimum_iptc).at_xpath('//mods/titleInfo/title')&.text).to eq('A photo')
    end

    it 'emits the keyword as a subject/topic' do
      expect(doc(minimum_iptc).xpath('//mods/subject/topic').map(&:text)).to eq(['athletics'])
    end

    it 'emits the photographs genre' do
      expect(doc(minimum_iptc).at_xpath('//mods/genre')&.text).to eq('photographs')
    end

    it 'declares aat authority on the genre' do
      expect(doc(minimum_iptc).at_xpath('//mods/genre')['authority']).to eq('aat')
    end

    it 'emits the physical description block' do
      pd = doc(minimum_iptc).at_xpath('//mods/physicalDescription')
      expect(pd.at_xpath('form')&.text).to eq('electronic')
      expect(pd.at_xpath('digitalOrigin')&.text).to eq('born digital')
      expect(pd.at_xpath('extent')&.text).to eq('1 photograph')
    end
  end

  describe 'required-field validation' do
    it 'raises if Headline is missing' do
      expect { described_class.call(iptc: { Keywords: ['x'] }) }
        .to raise_error(Iptc::MODSBuilder::MissingRequiredField, /Headline/)
    end

    it 'raises if Headline is blank' do
      expect { described_class.call(iptc: { Headline: '', Keywords: ['x'] }) }
        .to raise_error(Iptc::MODSBuilder::MissingRequiredField, /Headline/)
    end

    it 'raises if both Keywords and Subject are absent' do
      expect { described_class.call(iptc: { Headline: 'A' }) }
        .to raise_error(Iptc::MODSBuilder::MissingRequiredField, /Keywords/)
    end

    it 'falls back to Subject if Keywords is absent (v1 parity)' do
      expect { described_class.call(iptc: { Headline: 'A', Subject: ['fallback'] }) }
        .not_to raise_error
    end
  end

  describe 'byline parsing' do
    it 'splits a comma-form byline into first/last' do
      iptc = minimum_iptc.merge(:'By-line' => 'Doe, Jane')
      creator = doc(iptc).at_xpath('//mods/name[@type="personal"]')
      expect(creator.at_xpath('namePart[@type="given"]')&.text).to eq('Jane')
      expect(creator.at_xpath('namePart[@type="family"]')&.text).to eq('Doe')
    end

    it 'splits a semicolon-form byline' do
      iptc = minimum_iptc.merge(:'By-line' => 'Smith; Bob')
      creator = doc(iptc).at_xpath('//mods/name[@type="personal"]')
      expect(creator.at_xpath('namePart[@type="given"]')&.text).to eq('Bob')
      expect(creator.at_xpath('namePart[@type="family"]')&.text).to eq('Smith')
    end

    it 'falls back to Namae for a bare-name byline' do
      iptc = minimum_iptc.merge(:'By-line' => 'Jane Doe')
      creator = doc(iptc).at_xpath('//mods/name[@type="personal"]')
      expect(creator.at_xpath('namePart[@type="given"]')&.text).to eq('Jane')
      expect(creator.at_xpath('namePart[@type="family"]')&.text).to eq('Doe')
    end

    it 'warns and omits the creator when the byline cannot be parsed' do
      result = described_class.call(iptc: minimum_iptc.merge(:'By-line' => '????'))
      expect(result.warnings).to include(match(/By-line could not be parsed/))
      d = Nokogiri::XML(result.xml).remove_namespaces!
      expect(d.at_xpath('//mods/name[@type="personal"]')).to be_nil
    end

    it 'uses By-lineTitle as the roleTerm when present' do
      iptc = minimum_iptc.merge(:'By-line' => 'Doe, Jane', :'By-lineTitle' => 'Photographer')
      expect(doc(iptc).at_xpath('//mods/name/role/roleTerm')&.text).to eq('Photographer')
    end

    it 'defaults the roleTerm to Creator when By-lineTitle is absent' do
      iptc = minimum_iptc.merge(:'By-line' => 'Doe, Jane')
      expect(doc(iptc).at_xpath('//mods/name/role/roleTerm')&.text).to eq('Creator')
    end
  end

  describe 'date parsing' do
    it 'formats a Time as ISO yyyy-mm-dd' do
      iptc = minimum_iptc.merge(DateTimeOriginal: Time.utc(2024, 5, 28, 12, 0))
      expect(doc(iptc).at_xpath('//mods/originInfo/dateCreated')&.text).to eq('2024-05-28')
    end

    it 'records w3cdtf encoding and keyDate=yes' do
      iptc = minimum_iptc.merge(DateTimeOriginal: Time.utc(2024, 5, 28))
      d = doc(iptc).at_xpath('//mods/originInfo/dateCreated')
      expect(d['encoding']).to eq('w3cdtf')
      expect(d['keyDate']).to eq('yes')
    end

    it 'warns and omits the dateCreated when DateTimeOriginal is not a Time' do
      result = described_class.call(iptc: minimum_iptc.merge(DateTimeOriginal: 'not a date'))
      expect(result.warnings).to include(match(/DateTimeOriginal.*not a valid date/))
      expect(Nokogiri::XML(result.xml).remove_namespaces!.at_xpath('//mods/originInfo/dateCreated'))
        .to be_nil
    end
  end

  describe 'geographic subject' do
    it 'joins City and State with a comma + space' do
      iptc = minimum_iptc.merge(City: 'Boston', State: 'MA')
      expect(doc(iptc).at_xpath('//mods/subject/geographic')&.text).to eq('Boston, MA')
    end

    it 'omits the geographic subject when both City and State are blank' do
      expect(doc(minimum_iptc).at_xpath('//mods/subject/geographic')).to be_nil
    end

    it 'tolerates City without State' do
      iptc = minimum_iptc.merge(City: 'Boston')
      expect(doc(iptc).at_xpath('//mods/subject/geographic')&.text).to eq('Boston')
    end
  end

  describe 'category classification' do
    it 'maps known v1 category codes to their labels' do
      iptc = minimum_iptc.merge(Category: 'ATH')
      expect(doc(iptc).at_xpath('//mods/classification')&.text).to eq('athletics')
    end

    it 'downcases unknown category codes' do
      iptc = minimum_iptc.merge(Category: 'SomethingNew')
      expect(doc(iptc).at_xpath('//mods/classification')&.text).to eq('somethingnew')
    end

    it 'appends supplemental categories with a " -- " separator' do
      iptc = minimum_iptc.merge(Category: 'ATH', SupplementalCategories: %w[Football Intramural])
      expect(doc(iptc).at_xpath('//mods/classification')&.text)
        .to eq('athletics -- football -- intramural')
    end

    it 'replaces underscores in supplemental categories with spaces' do
      iptc = minimum_iptc.merge(Category: 'ATH', SupplementalCategories: ['Track_and_Field'])
      expect(doc(iptc).at_xpath('//mods/classification')&.text)
        .to eq('athletics -- track and field')
    end

    it 'omits classification entirely when Category is blank' do
      expect(doc(minimum_iptc).at_xpath('//mods/classification')).to be_nil
    end
  end

  describe 'description / abstract' do
    it 'emits Description as abstract' do
      iptc = minimum_iptc.merge(Description: 'A long caption.')
      expect(doc(iptc).at_xpath('//mods/abstract')&.text).to eq('A long caption.')
    end

    it 'omits abstract when Description is blank' do
      expect(doc(minimum_iptc).at_xpath('//mods/abstract')).to be_nil
    end
  end

  describe 'Source publisher' do
    it 'emits Source as originInfo/publisher when present' do
      iptc = minimum_iptc.merge(Source: 'Northeastern University')
      expect(doc(iptc).at_xpath('//mods/originInfo/publisher')&.text)
        .to eq('Northeastern University')
    end
  end

  describe 'multiple keywords' do
    it 'emits one subject/topic per keyword in order' do
      iptc = minimum_iptc.merge(Keywords: %w[athletics campus alumni])
      expect(doc(iptc).xpath('//mods/subject/topic').map(&:text))
        .to eq(%w[athletics campus alumni])
    end
  end

  describe 'namespace declaration' do
    it 'declares the MODS namespace as the default' do
      xml = described_class.call(iptc: minimum_iptc).xml
      expect(xml).to include('xmlns="http://www.loc.gov/mods/v3"')
    end

    it 'declares the schemaLocation for MODS 3-5' do
      xml = described_class.call(iptc: minimum_iptc).xml
      expect(xml).to include('mods-3-5.xsd')
    end
  end
end
