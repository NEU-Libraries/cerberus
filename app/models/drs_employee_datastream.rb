# employee datastream: persistence for nuid and name, allowing us to index with solr
class DrsEmployeeDatastream < ActiveFedora::OmDatastream
  set_terminology do |t|
    t.root(:path=>"fields" ) 
    t.nuid :index_as=>[:stored_searchable]
    t.name    
  end

  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.fields
    end
    builder.doc
  end
end