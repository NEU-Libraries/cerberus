# frozen_string_literal: true

module MODSBuilder
  def mods_template
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.mods('xmlns:drs' => 'https://repository.neu.edu/spec/v1', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
               'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd',
               'xmlns:niec' => 'http://repository.neu.edu/schema/niec',
               'xmlns:dcterms' => 'http://purl.org/dc/terms/',
               'xmlns:dwc' => 'http://rs.tdwg.org/dwc/terms/',
               'xmlns:dwr' => 'http://rs.tdwg.org/dwc/xsd/simpledarwincore/') do
        xml.parent.namespace = xml.parent.namespace_definitions.find { |ns| ns.prefix == 'mods' }
        xml.titleInfo('usage' => 'primary') do
          xml.title ''
        end
        xml.titleInfo('type' => 'alternative') do
          xml.title ''
        end
        xml.abstract
        xml.name('type' => 'personal')
        xml.name('type' => 'corporate')
        xml.originInfo do
          xml.place do
            xml.placeTerm
          end
          xml.dateCreated('keyDate' => 'yes', 'encoding' => 'w3cdtf')
        end
        xml.language do
          xml.languageTerm
        end
        xml.note
        xml.subject do
          xml.topic ''
        end
        xml.identifier('type' => 'hdl', 'displayLabel' => 'Permanent URL')
        xml.typeOfResource

        xml.recordInfo do
          xml.recordContentSource
          xml.recordOrigin
          xml.descriptionStandard
          xml.languageOfCataloging do
            xml.languageTerm
          end
        end

        xml.physicalDescription do
          xml.form
        end

        xml.extension('displayLabel' => 'scholarly_object') do
          xml.scholarly_object do
            xml.parent.namespace = nil

            xml.category { xml.parent.namespace = nil }
            xml.department { xml.parent.namespace = nil }
            xml.degree { xml.parent.namespace = nil }
            xml.college { xml.parent.namespace = nil }

            xml.course_info do
              xml.parent.namespace = nil
              xml.course_number { xml.parent.namespace = nil }
              xml.course_title { xml.parent.namespace = nil }
            end
          end
        end
        xml['mods'].extension do
          xml['niec'].niec
          xml['dwr'].SimpleDarwinRecord
        end
      end
    end
    builder.to_xml
  end
end
