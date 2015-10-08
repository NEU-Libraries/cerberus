module ActiveFedora
  class OmDatastream < Datastream

    def datastream_content
      @datastream_content ||= Nokogiri::XML(super, nil, 'UTF-8').to_xml
    end

    def to_xml(xml = nil)
      xml = self.ng_xml if xml.nil?
      ng_xml = self.ng_xml
      if ng_xml.respond_to?(:root) && ng_xml.root.nil? && self.class.respond_to?(:root_property_ref) && !self.class.root_property_ref.nil?
        ng_xml = self.class.generate(self.class.root_property_ref, "")
        if xml.root.nil?
          xml = ng_xml
        end
      end

      unless xml == ng_xml || ng_xml.root.nil?
        if xml.kind_of?(Nokogiri::XML::Document)
            xml.root.add_child(ng_xml.root)
        elsif xml.kind_of?(Nokogiri::XML::Node)
            xml.add_child(ng_xml.root)
        else
            raise "You can only pass instances of Nokogiri::XML::Node into this method.  You passed in #{xml}"
        end
      end

      return xml.to_xml
    end

  end
end
