# frozen_string_literal: true

module MODSBuilder
  def template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.root {
        xml.products {
          xml.widget {
            xml.id_ "10"
            xml.name "Awesome widget"
          }
        }
      }
    end
    builder.to_xml
  end
end
