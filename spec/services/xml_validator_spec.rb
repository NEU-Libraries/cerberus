# frozen_string_literal: true

require 'rails_helper'

describe XmlValidator do
  let(:schema_uri) { 'http://www.loc.gov/standards/mods/v3/mods-3-7.xsd' }
  let(:passing_schema) { instance_double(Nokogiri::XML::Schema, validate: []) }
  let(:valid_mods) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xsi:schemaLocation="http://www.loc.gov/mods/v3 #{schema_uri}">
        <mods:titleInfo><mods:title>Test</mods:title></mods:titleInfo>
      </mods:mods>
    XML
  end

  before do
    # Mock at the Kataba boundary — these unit tests exercise the validator's
    # wiring (which phases run, in what order, with what errors), not the
    # specifics of any real XSD.
    allow(Kataba).to receive(:fetch_schema).with(schema_uri).and_return(passing_schema)
  end

  describe '#call' do
    it 'returns an empty array for well-formed MODS that passes its schema' do
      expect(XmlValidator.call(xml: valid_mods)).to eq([])
    end

    it 'returns a Nokogiri::XML::SyntaxError for unparseable XML and skips later phases' do
      errors = XmlValidator.call(xml: '<mods:mods><titleInfo>unclosed')
      expect(errors.size).to eq(1)
      expect(errors.first).to be_a(Nokogiri::XML::SyntaxError)
      expect(Kataba).not_to have_received(:fetch_schema)
    end

    it 'flags documents that do not declare the MODS namespace' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://example.com #{schema_uri}">
          <child/>
        </root>
      XML
      errors = XmlValidator.call(xml: xml)
      expect(errors).to include(a_string_matching(/xmlns:mods/))
    end

    it 'flags documents whose root has no schemaLocation attribute' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3">
          <mods:titleInfo><mods:title>Test</mods:title></mods:titleInfo>
        </mods:mods>
      XML
      errors = XmlValidator.call(xml: xml)
      expect(errors).to include(a_string_matching(/schemaLocation/))
      expect(Kataba).not_to have_received(:fetch_schema)
    end

    it 'propagates XSD validation errors from Kataba.fetch_schema(...).validate' do
      schema_error = Nokogiri::XML::SyntaxError.allocate
      allow(schema_error).to receive(:to_s).and_return('element title not allowed here')
      failing_schema = instance_double(Nokogiri::XML::Schema, validate: [schema_error])
      allow(Kataba).to receive(:fetch_schema).with(schema_uri).and_return(failing_schema)

      errors = XmlValidator.call(xml: valid_mods)
      expect(errors).to include(schema_error)
    end

    it 'surfaces a friendly error when the schema service returns an HTTP error' do
      allow(Kataba).to receive(:fetch_schema).with(schema_uri)
        .and_raise(OpenURI::HTTPError.new('503 Service Unavailable', nil))
      errors = XmlValidator.call(xml: valid_mods)
      expect(errors).to include(a_string_matching(/Could not fetch schema.*503/))
    end

    it 'surfaces a friendly error when the schema service is unreachable' do
      allow(Kataba).to receive(:fetch_schema).with(schema_uri)
        .and_raise(SocketError.new('getaddrinfo: Name or service not known'))
      errors = XmlValidator.call(xml: valid_mods)
      expect(errors).to include(a_string_matching(/Could not fetch schema.*SocketError/))
    end

    it 'surfaces a friendly error when open-uri refuses a HTTPS→HTTP redirect' do
      allow(Kataba).to receive(:fetch_schema).with(schema_uri)
        .and_raise(RuntimeError.new('redirection forbidden: https://example.com -> http://example.com'))
      errors = XmlValidator.call(xml: valid_mods)
      expect(errors).to include(a_string_matching(/redirection forbidden/))
    end

    it 're-raises RuntimeErrors that are not open-uri redirect refusals' do
      allow(Kataba).to receive(:fetch_schema).with(schema_uri)
        .and_raise(RuntimeError.new('some unrelated bug'))
      expect { XmlValidator.call(xml: valid_mods) }.to raise_error(RuntimeError, 'some unrelated bug')
    end

    it 'continues fetching other schemas when one URI fails' do
      other_uri = 'http://example.com/other.xsd'
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xsi:schemaLocation="http://www.loc.gov/mods/v3 #{schema_uri} http://example.com #{other_uri}">
          <mods:titleInfo><mods:title>Test</mods:title></mods:titleInfo>
        </mods:mods>
      XML
      allow(Kataba).to receive(:fetch_schema).with(schema_uri)
        .and_raise(OpenURI::HTTPError.new('503 Service Unavailable', nil))
      allow(Kataba).to receive(:fetch_schema).with(other_uri).and_return(passing_schema)

      errors = XmlValidator.call(xml: xml)
      expect(errors).to include(a_string_matching(/Could not fetch schema #{Regexp.escape(schema_uri)}/))
      expect(Kataba).to have_received(:fetch_schema).with(other_uri)
    end

    it 'fetches one schema per distinct namespace in schemaLocation' do
      other_uri = 'http://example.com/other.xsd'
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xsi:schemaLocation="http://www.loc.gov/mods/v3 #{schema_uri} http://example.com #{other_uri}">
          <mods:titleInfo><mods:title>Test</mods:title></mods:titleInfo>
        </mods:mods>
      XML
      allow(Kataba).to receive(:fetch_schema).with(other_uri).and_return(passing_schema)

      XmlValidator.call(xml: xml)
      expect(Kataba).to have_received(:fetch_schema).with(schema_uri)
      expect(Kataba).to have_received(:fetch_schema).with(other_uri)
    end
  end
end
