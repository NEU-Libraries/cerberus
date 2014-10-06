require 'spec_helper'

describe Cerberus::ModsExtensions::NIEC do
  class NiecTester < ActiveFedora::OmDatastream
    include OM::XML::Document

    set_terminology do |t|
      t.root(path: 'root',
             'xmlns:niec' => 'niec_schema',
             'xmlns:mods' => 'mods_schema')
    end

    include Cerberus::ModsExtensions::NIEC

    def self.xml_template
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.root('xmlns:niec' => 'niec_schema', 'xmlns:mods' => 'mods_schema')
      end
      builder.doc
    end
  end

  let(:ds) { NiecTester.new }

  it "can set the niec title field" do
    ds.niec_title = "Sample NIEC Document"
    expect(ds.niec_title).to eq ["Sample NIEC Document"]
  end

  it "can set the niec identifier field" do
    ds.niec_identifier = "hdl:123"
    expect(ds.niec_identifier).to eq ["hdl:123"]
  end

  it "can set the 'type' attribute on niec identifiers" do
    ds.niec_identifier = "hdl:123"
    ds.niec_identifier_type = "hdl"
    expect(ds.niec_identifier_type).to eq ["hdl"]
  end

  it "can set the niec fullName field" do
    ds.niec_full_name = "Will Jackson"
    expect(ds.niec_full_name).to eq ["Will Jackson"]
  end

  it "can set the 'authority' attribute on fullNames" do
    ds.niec_full_name_authority = "local"
    expect(ds.niec_full_name_authority).to eq ["local"]
  end

  it "can set the 'type' attribute on fullNames" do
    ds.niec_full_name_type = "personal"
    expect(ds.niec_full_name_type).to eq ["personal"]
  end

  it "can set the niec role field" do
    ds.niec_role = "Author"
    expect(ds.niec_role).to eq ["Author"]
  end

  it "can set the niec gender field" do
    ds.niec_gender = "Male"
    expect(ds.niec_gender).to eq ["Male"]
  end

  it "can set the niec age field" do
    ds.niec_age = "Baby"
    expect(ds.niec_age).to eq ["Baby"]
  end

  it "can set the niec race field" do
    ds.niec_race = "Asian"
    expect(ds.niec_race).to eq ["Asian"]
  end

  describe "Solrization" do

  end
end
