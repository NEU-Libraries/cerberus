class ModsMetadata < ActiveFedora::OmDatastream

  set_terminology do |t|
    t.root(path: "mods")
    t.title
    t.author
  end

  def self.xml_template
    Nokogiri::XML.parse("<mods/>")
  end

end
