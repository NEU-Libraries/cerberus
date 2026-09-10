# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Metadata::DoubleEscapes do
  describe '.any?' do
    it 'sees a reference escaped twice' do
      expect(described_class.any?('<abstract>XM&amp;lt;LGBT/&amp;gt;</abstract>')).to be true
    end

    it 'leaves a reference escaped once alone -- that one is correct' do
      expect(described_class.any?('<title>XM&lt;LGBT/&gt;</title>')).to be false
    end

    it 'is not fooled by an ordinary ampersand' do
      expect(described_class.any?('<title>Ben &amp; Jerry</title>')).to be false
    end

    it 'ignores a nested entity XML does not predefine, which it could not repair' do
      expect(described_class.any?('<title>a&amp;nbsp;b</title>')).to be false
    end
  end

  describe '.decode' do
    it 'restores the character a doubled escape spells out' do
      expect(described_class.decode('XM&amp;lt;LGBT/&amp;gt;')).to eq('XM&lt;LGBT/&gt;')
    end

    it 'restores a doubled ampersand' do
      expect(described_class.decode('Ben &amp;amp; Jerry')).to eq('Ben &amp; Jerry')
    end

    it 'restores the quote entities too' do
      expect(described_class.decode('&amp;quot;a&amp;apos;b&amp;quot;')).to eq('&quot;a&apos;b&quot;')
    end

    it 'takes one level off, not all of them' do
      expect(described_class.decode('&amp;amp;lt;')).to eq('&amp;lt;')
    end

    it 'leaves an ordinary ampersand alone' do
      expect(described_class.decode('Ben &amp; Jerry')).to eq('Ben &amp; Jerry')
    end

    # Decoding this would write `&nbsp;` into the document, which XML cannot
    # parse: a valid record would stop loading, and the curator would be left
    # holding a document no worse-formed than the repair that broke it.
    it 'refuses an entity XML does not predefine, whose decoded form would not parse' do
      expect(described_class.decode('a&amp;nbsp;b')).to eq('a&amp;nbsp;b')
    end

    it 'passes nil straight through' do
      expect(described_class.decode(nil)).to be_nil
    end

    # A record can carry both depths at once, and only the deeper one is wrong.
    # The correct field is the reference for what the other should have held.
    it 'repairs the abstract of a record whose title is already correct' do
      xml = <<~XML
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3">
          <mods:titleInfo><mods:title>XM&lt;LGBT/&gt;</mods:title></mods:titleInfo>
          <mods:abstract>called XM&amp;lt;LGBT/&amp;gt;.</mods:abstract>
        </mods:mods>
      XML

      decoded = described_class.decode(xml)

      expect(decoded).to include('<mods:title>XM&lt;LGBT/&gt;</mods:title>')
      expect(decoded).to include('<mods:abstract>called XM&lt;LGBT/&gt;.</mods:abstract>')
    end

    # The repair exists to make the two agree, so assert that they do — after
    # decoding, both text nodes carry the same characters.
    it 'leaves the title and the abstract holding the same text' do
      xml = '<r><t>XM&lt;LGBT/&gt;</t><a>XM&amp;lt;LGBT/&amp;gt;</a></r>'

      doc = Nokogiri::XML(described_class.decode(xml))

      expect(doc.at_xpath('//a').text).to eq(doc.at_xpath('//t').text)
      expect(doc.at_xpath('//a').text).to eq('XM<LGBT/>')
    end
  end

  describe '.report' do
    it 'is silent about a clean document' do
      expect(described_class.report('<title>XM&lt;LGBT/&gt;</title>')).to be_nil
    end

    it 'names the reference, its line, and what a reader sees instead' do
      report = described_class.report("<mods>\n  <abstract>XM&amp;lt;x</abstract>\n</mods>")

      expect(report).to include('escapes a character twice: &amp;lt; on line 2')
      expect(report).to include('A reader sees &lt; where the record means <')
    end

    it 'says the XML is valid, so the curator knows Save is not blocked' do
      expect(described_class.report('a&amp;lt;b')).to include('The XML is valid, so Save takes it as it stands')
    end

    it 'reads as a plural when the document holds more than one' do
      report = described_class.report('XM&amp;lt;LGBT/&amp;gt;')

      expect(report).to include('escapes characters twice: &amp;lt; on line 1, &amp;gt; on line 1')
    end

    # A migrated abstract carries the same reference in every paragraph. Listing
    # every hit buries the fix the message exists to give.
    it 'reports a repeated reference once, on the line it first appears' do
      report = described_class.report("&amp;lt;\n&amp;lt;\n&amp;lt;")

      expect(report).to include('&amp;lt; on line 1')
      expect(report.scan('&amp;lt;').length).to eq(1)
    end
  end
end
