class NuModsCollectionDatastream < ActiveFedora::OmDatastream 
  include OM::XML::Document 

  set_terminology do |t|
    t.root(path: 'mods', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd')
    t.title_info(path: 'titleInfo', namespace_prefix: 'mods'){
      t.title(path: 'title', namespace_prefix: 'mods') 
    }
    t.abstract(path: 'abstract', namespace_prefix: 'mods') 
    t.identifier(path: 'identifier', namespace_prefix: 'mods')
    t.type_of_resource(path: 'typeOfResource', 'collection' => 'yes', namespace_prefix: 'mods') 
    t.title(proxy: [:title_info, :title]) 
  end

  def self.xml_template 
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.mods('xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd'){ 
        xml.parent.namespace = xml.parent.namespace_definitions.find { |ns| ns.prefix=="mods" } 
        xml['mods'].titleInfo {
          xml['mods'].title 
        } 
        xml['mods'].abstract
        xml['mods'].identifier
        xml['mods'].typeOfResource('collection' => 'yes') 
      }
    end
    builder.doc 
  end
end