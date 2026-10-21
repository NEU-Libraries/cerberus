# frozen_string_literal: true

require 'rails_helper'

describe DarwinCoreRecordValidator do
  let(:schema_uri) { 'http://rs.tdwg.org/dwc/xsd/tdwg_dwc_simple.xsd' }
  let(:record)     { file_fixture('dwc-record.xml').read }

  before do
    allow(Kataba).to receive(:fetch_schema).with(schema_uri)
                                           .and_return(instance_double(Nokogiri::XML::Schema, validate: []))
  end

  it 'accepts the TDWG example record' do
    expect(described_class.call(xml: record)).to eq([])
  end

  # The TDWG page once published this example with a mismatched end tag and a
  # misspelt datum. Only the tag is a well-formedness error.
  it 'refuses the broken TDWG example at the parse' do
    errors = described_class.call(xml: file_fixture('dwc-record-broken.xml').read)

    expect(errors.size).to eq(1)
    expect(errors.first).to be_a(Nokogiri::XML::SyntaxError)
    expect(Kataba).not_to have_received(:fetch_schema)
  end

  it 'passes on the errors the schema reports' do
    schema_error = Nokogiri::XML::SyntaxError.allocate
    allow(schema_error).to receive(:to_s).and_return("Element 'dwc:notATerm': This element is not expected.")
    allow(Kataba).to receive(:fetch_schema).with(schema_uri)
                                           .and_return(instance_double(Nokogiri::XML::Schema, validate: [schema_error]))

    expect(described_class.call(xml: record)).to eq([schema_error])
  end

  it 'refuses a document whose root is not a record set' do
    wrong_root = record.sub('<dwr:SimpleDarwinRecordSet', '<dwr:SimpleDarwinRecordList')
                       .sub('</dwr:SimpleDarwinRecordSet>', '</dwr:SimpleDarwinRecordList>')

    expect(described_class.call(xml: wrong_root)).to eq([described_class::NOT_A_RECORD_SET])
  end

  it 'refuses a record set holding two records' do
    two = record.sub('</dwr:SimpleDarwinRecordSet>',
                     '<dwr:SimpleDarwinRecord><dwc:sex>female</dwc:sex></dwr:SimpleDarwinRecord></dwr:SimpleDarwinRecordSet>')

    expect(described_class.call(xml: two)).to eq([described_class.record_count_error(2)])
  end

  it 'refuses an empty record set' do
    empty = record.sub(%r{<dwr:SimpleDarwinRecord>.*</dwr:SimpleDarwinRecord>}m, '')

    expect(described_class.call(xml: empty)).to eq([described_class.record_count_error(0)])
  end

  # The schema accepts both, but Atlas keys both as `type` and refuses the pair.
  it 'refuses dc:type beside dcterms:type' do
    both = record.sub('<dc:type>PhysicalObject</dc:type>',
                      '<dc:type>PhysicalObject</dc:type><dcterms:type>PhysicalObject</dcterms:type>')

    expect(described_class.call(xml: both)).to eq([described_class.duplicate_term_error('type')])
  end

  it 'ignores a blank repeat, as Atlas does' do
    blank = record.sub('<dc:type>PhysicalObject</dc:type>', '<dc:type>PhysicalObject</dc:type><dcterms:type> </dcterms:type>')

    expect(described_class.call(xml: blank)).to eq([])
  end

  it 'accepts the record-set namespace under any prefix' do
    renamed = record.gsub('dwr:', 'rs:').sub('xmlns:dwr=', 'xmlns:rs=')

    expect(described_class.call(xml: renamed)).to eq([])
  end

  # The mirror list is what points Kataba at the corrected copies, and a value
  # that names a missing file fails only when a record is validated.
  it 'names a corrected TDWG schema that exists for every Darwin Core mirror entry' do
    mirrors = YAML.load_file(Rails.root.join('config/kataba_mirrors.yml'))
                  .select { |uri, _| uri.include?('tdwg') }

    expect(mirrors.size).to eq(12)
    mirrors.each_value do |path|
      expect(Rails.root.join('config', path)).to exist
    end
  end
end
