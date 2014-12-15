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

  # Exhaustive testing of what amount to basic setters/getters
  # seems like a waste of time - test just enough to verify that
  # each of the array definition helpers dtrt

  it "can write to the niec:niec space" do
    ds.niec_comment = "This is okay"
    expect(ds.niec_comment).to eq ["This is okay"]
  end

  it "can write to the niec:name space" do
    ds.niec_full_name = "William Jackson"
    ds.niec_role      = "Developer"

    expect(ds.niec_full_name).to eq ["William Jackson"]
    expect(ds.niec_role).to eq ["Developer"]
  end

  it "can write to the niec:origin space" do
    ds.niec_publisher_name = "Smith Print"
    expect(ds.niec_publisher_name).to eq ["Smith Print"]
  end

  it "can write to the niec:language space" do
    ds.niec_signed_language = "ASL"
    ds.niec_spoken_language = "English"

    expect(ds.niec_signed_language).to eq ["ASL"]
    expect(ds.niec_spoken_language).to eq ["English"]
  end

  it "can write to the niec:contentDescription space" do
    ds.niec_genre = "Mystery"
    expect(ds.niec_genre).to eq ["Mystery"]
  end

  describe "Solrization" do
    let(:solr_response) { ds.generate_niec_solr_hash }

    it "returns an empty hash with no values" do
      expect(solr_response).to be_empty
    end

    it "knows how to write text types" do
      str = "This is a test comment."
      ds.niec_comment = str
      expect(solr_response["niec_comment_tesim"]).to eq [str]
    end

    it "knows how to write string types" do
      ds.niec_fingerspelling_extent = "Extensive"
      expect(solr_response["niec_fingerspelling_extent_ssim"]).to eq ["Extensive"]
    end
  end
end
