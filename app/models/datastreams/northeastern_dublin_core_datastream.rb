class NortheasternDublinCoreDatastream < ActiveFedora::OmDatastream
  include OM::XML::Document 

  set_terminology do |t| 
    t.root(path: 'dc', namespace_prefix: 'oai_dc', 'xmlns:oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/', 'xmlns:dc' => 'http://purl.org/dc/elements/1.1/', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd')
    t.nu_title(path: 'title', namespace_prefix: 'dc')
    t.nu_type(path: 'type', namespace_prefix: 'dc')
    t.nu_identifier(path: 'identifier', namespace_prefix: 'dc')
  end


  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml| 
      xml['oai_dc'].dc('xmlns:oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/', 'xmlns:dc' => 'http://purl.org/dc/elements/1.1/', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 
                    'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd'){
        xml['dc'].title
        xml['dc'].type
        xml['dc'].identifier
      }
    end
    builder.doc 
  end
end