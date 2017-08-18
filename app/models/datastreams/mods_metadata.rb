class ModsMetadata < ActiveFedora::OmDatastream

  set_terminology do |t|
    t.root(path: 'mods',
           'xmlns:drs' => 'https://repository.neu.edu/spec/v1',
           'xmlns:mods' => 'http://www.loc.gov/mods/v3',
           'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
           'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd',
           'xmlns:niec' => 'http://repository.neu.edu/schema/niec',
           'xmlns:dcterms' => "http://purl.org/dc/terms/",
           'xmlns:dwc' => "http://rs.tdwg.org/dwc/terms/",
           'xmlns:dwr' => "http://rs.tdwg.org/dwc/xsd/simpledarwincore/")

    t.key_date(path: '*', namespace_prefix: 'mods', attributes: { keyDate: "yes" }){
      t.qualifier(path: { attribute: "qualifier" })
    }

    t.title_info(path: 'mods/mods:titleInfo', namespace_prefix: 'mods', attributes: { type: :none }){
      t.title(path: 'title', namespace_prefix: 'mods', index_as: [:stored_searchable, :sortable])
      t.non_sort(path: 'nonSort', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.sub_title(path: 'subTitle', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.part_name(path: 'partName', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.part_number(path: 'partNumber', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.supplied(path: {attribute: 'supplied'})
    }

    t.alternate_title(path: 'mods/mods:titleInfo', namespace_prefix: 'mods', attributes: {type: "alternative"}){
      t.title(path: 'title', namespace_prefix: 'mods')
      t.non_sort(path: 'nonSort', namespace_prefix: 'mods')
      t.sub_title(path: 'subTitle', namespace_prefix: 'mods')
      t.part_name(path: 'partName', namespace_prefix: 'mods')
      t.part_number(path: 'partNumber', namespace_prefix: 'mods')
    }

    t.all_titles(path:'titleInfo', namespace_prefix:'mods'){
      t.title(path:'title', namespace_prefix: 'mods')
      t.non_sort(path: 'nonSort', namespace_prefix: 'mods')
    }

    t.abstract(path: 'abstract', namespace_prefix: 'mods', index_as: [:stored_searchable])

    t.name(path: 'name', namespace_prefix: 'mods', attributes: { type: :none }){
      t.name_part(path: 'namePart', namespace_prefix: 'mods', attributes: { type: :none }, index_as: [:stored_searchable, :facetable])
    }

    t.personal_name(path: 'mods/mods:name', namespace_prefix: 'mods', attributes: { type: 'personal' }){
      t.usage(path: { attribute: "usage" })
      t.authority(path: { attribute: 'authority' })
      t.authority_uri(path: {attribute: 'authorityURI'})
      t.value_uri(path: {attribute: 'valueURI'})
      t.name_part(path: 'namePart', namespace_prefix: 'mods', attributes: { type: :none }, index_as: [:stored_searchable, :facetable])
      t.name_part_given(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'given' })
      t.name_part_family(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'family' })
      t.name_part_date(path: 'namePart', namespace_prefix: 'mods', attributes: {type: 'date'})
      t.name_part_address(path: 'namePart', namespace_prefix: 'mods', attributes: {type: 'termsOfAddress'})
      t.role(namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.role_term(path: 'roleTerm', namespace_prefix: 'mods'){
          t.authority(path: { attribute: 'authority'})
          t.type(path: { attribute: 'type'})
          t.authority_uri(path: {attribute: 'authorityURI'})
          t.value_uri(path: {attribute: 'valueURI'})
        }
      }
      t.affiliation(namespace_prefix: 'mods', attribute: 'affiliation')
    }

    t.author_name_part(:path=>"roleTerm[.='Author']/../../mods:namePart", namespace_prefix: 'mods')
    t.author_given(:path=>"roleTerm[.='Author']/../../mods:namePart", namespace_prefix: 'mods', attributes: { type: 'given' })
    t.author_family(:path=>"roleTerm[.='Author']/../../mods:namePart", namespace_prefix: 'mods', attributes: { type: 'family' })

    t.corporate_name(path: 'mods/mods:name', namespace_prefix: 'mods', attributes: { type: 'corporate' }){
      t.usage(path: { attribute: "usage" })
      t.authority(path: { attribute: 'authority' })
      t.authority_uri(path: {attribute: 'authorityURI'})
      t.value_uri(path: {attribute: 'valueURI'})
      t.name_part(path: 'namePart', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
      t.role(namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.role_term(path: 'roleTerm', namespace_prefix: 'mods'){
          t.authority(path: { attribute: 'authority'})
          t.type(path: { attribute: 'type'})
          t.authority_uri(path: {attribute: 'authorityURI'})
          t.value_uri(path: {attribute: 'valueURI'})
        }
      }
      t.affiliation(namespace_prefix: 'mods', attribute: 'affiliation')
    }

    t.type_of_resource(path: 'typeOfResource', namespace_prefix: 'mods')

    t.genre(path: 'genre', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable]){
      t.authority(path: { attribute: 'authority' })
      t.authority_uri(path: { attribute: 'authorityURI' })
      t.value_uri(path: { attribute: 'valueURI' })
    }

    t.origin_info(path: 'originInfo', namespace_prefix: 'mods'){
      t.publisher(path: 'publisher', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.place(path: 'place', namespace_prefix: 'mods'){
        t.place_term(path: 'placeTerm', namespace_prefix: 'mods', attributes: { type: 'text' })
      }
      t.date_created(path: 'dateCreated', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable], attributes: { encoding: 'w3cdtf', keyDate: 'yes' }){
        t.point(path: {attribute: 'point'})
        t.qualifier(path: {attribute: 'qualifier'})
      }
      t.date_created_end(path: 'dateCreated', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf', point: 'end'}){
        t.qualifier(path: {attribute: 'qualifier'})
      }
      t.copyright(path: 'copyrightDate', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable], attributes: { encoding: 'w3cdtf' })
      t.date_issued(path: 'dateIssued', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable], attributes: { encoding: 'w3cdtf' })
      t.date_other(path: 'dateOther', namespace_prefix: 'mods', index_as: [:stored_searchable], attributes: { encoding: 'w3cdtf'})
      t.issuance(path: 'issuance', namespace_prefix: 'mods')
      t.edition(path: 'edition', namespace_prefix: 'mods')
      t.frequency(path: 'frequency', namespace_prefix: 'mods'){
        t.authority(path: { attribute: 'authority'})
      }
    }

    t.language(path: 'language', namespace_prefix: 'mods'){
      t.language_term(path: 'languageTerm', namespace_prefix: 'mods'){
        t.language_term_type(path: { attribute: 'type'})
        t.language_authority(path: { attribute: 'authority'})
        t.language_authority_uri(path: {attribute: 'authorityURI'})
        t.language_value_uri(path: { attribute: 'valueURI'})
      }
    }

    t.physical_description(path: 'physicalDescription', namespace_prefix: 'mods'){
      t.form(path: 'form', namespace_prefix: 'mods'){
        t.authority(path: {attribute: 'authority'})
      }
      t.digital_origin(path: 'digitalOrigin', namespace_prefix: 'mods')
      t.extent(path: 'extent', namespace_prefix: 'mods')
      t.reformatting_quality(path: 'reformattingQuality', namespace_prefix: 'mods')
    }

    t.record_info(path: 'recordInfo', namespace_prefix: 'mods'){
      t.record_content_source(path: 'recordContentSource', namespace_prefix: 'mods')
      t.record_origin(path: 'recordOrigin', namespace_prefix: 'mods')
      t.language_of_cataloging(path: 'languageOfCataloging', namespace_prefix: 'mods'){
        t.language_term(path: 'languageTerm', namespace_prefix: 'mods'){
          t.language_term_type(path: { attribute: 'type'})
          t.language_authority(path: { attribute: 'authority'})
          t.language_authority_uri(path: { attribute: 'authorityURI'})
          t.language_value_uri(path: { attribute: 'valueURI'})
        }
      }
      t.description_standard(path: 'descriptionStandard', namespace_prefix: 'mods'){
        t.authority(path: {attribute: 'authority'})
      }
      t.record_creation_date(path: 'recordCreationDate', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf' })
    }

    t.note(path: 'note', namespace_prefix: 'mods', index_as: [:stored_searchable]){
      t.type(path: { attribute: 'type' })
    }

    t.subject(path: 'mods/mods:subject', namespace_prefix: 'mods'){
      t.authority(path: {attribute: 'authority'})
      t.authority_uri(path: {attribute: 'authorityURI'})
      t.value_uri(path: {attribute: 'valueURI'})
      t.hierarchical_geographic(path: 'hierarchicalGeographic', namespace_prefix: 'mods'){
        t.continent(path: 'continent', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.country(path: 'country', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.region(path: 'region', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.state(path: 'state', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.territory(path: 'territory', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.county(path: 'county', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.city(path: 'city', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.city_section(path: 'citySection', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.island(path: 'island', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.area(path: 'area', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.extraterrestrial_area(path: 'extraterrestrialArea', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
      }
      t.cartographics(path: 'cartographics', namespace_prefix: 'mods'){
        t.scale(path: 'scale', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.projection(path: 'projection', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.coordinates(path: 'coordinates', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
      }
      t.geographic(path: 'geographic', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
      t.topic(path: 'topic', namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.authority(path: { attribute: 'authority' })
      }
      t.scoped_topic(path: 'topic', namespace_prefix: 'mods', attributes: { authority: :any })
      t.name(path: 'name', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable]){
        t.type(path: {attribute: 'type'})
        t.name_part(path: 'namePart', namespace_prefix: 'mods', attributes: { type: :none }, index_as: [:stored_searchable, :facetable])
        t.name_part_given(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'given' })
        t.name_part_family(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'family' })
        t.name_part_date(path: 'namePart', namespace_prefix: 'mods', attributes: {type: 'date'})
        t.name_part_address(path: 'namePart', namespace_prefix: 'mods', attributes: {type: 'termsOfAddress'})
        t.affiliation(namespace_prefix: 'mods', attribute: 'affiliation')
        t.authority(path: { attribute: 'authority' })
        t.authority_uri(path: {attribute: 'authorityURI'})
        t.value_uri(path: {attribute: 'valueURI'})
      }
      t.temporal(path: 'temporal', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf' }){
        t.point(path: {attribute: 'point'})
        t.qualifier(path: {attribute: 'qualifier'})
      }
      t.title_info(path: 'titleInfo', namespace_prefix: 'mods'){
        t.type(path: {attribute: 'type'})
        t.title(path: 'title', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
        t.non_sort(path: 'nonSort', namespace_prefix: 'mods')
        t.sub_title(path: 'subTitle', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
      }
      t.geographic_code(path: 'geographicCode', namespace_prefix: 'mods'){
        t.authority(path: {attribute: 'authority'})
        t.authority_uri(path: {attribute: 'authorityURI'})
        t.value_uri(path: {attribute: 'valueURI'})
      }
      t.genre(path: 'genre', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable]){
        t.authority(path: {attribute: 'authority'})
        t.authority_uri(path: {attribute: 'authorityURI'})
        t.value_uri(path: {attribute: 'valueURI'})
      }
    }

    t.identifier(path: 'identifier', namespace_prefix: 'mods', index_as: [:stored_searchable], attributes: { type: 'hdl' }){
      t.type(path: { attribute: 'type'})
      t.display_label(path: {attribute: 'displayLabel'})
    }

    t.identifier_generic(path: 'identifier', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable]){
      t.type(path: { attribute: 'type'})
      t.display_label(path: {attribute: 'displayLabel'})
    }

    t.access_condition(path: 'accessCondition', namespace_prefix: 'mods') {
      t.type(path: {attribute: 'type'})
    }

    t.classification(path: 'classification', namespace_prefix: 'mods')
    t.table_of_contents(path: 'tableOfContents', namespace_prefix: 'mods')

    t.related_item(path: 'relatedItem', namespace_prefix: 'mods'){
      t.type(path: {attribute: 'type'})
      t.title_info(path: 'titleInfo', namespace_prefix: 'mods'){
        t.title(path: 'title', namespace_prefix: 'mods')
      }
      t.part(path: 'part', namespace_prefix: 'mods'){
        t.detail(path: 'detail', namespace_prefix: 'mods'){
          t.type(path: {attribute: 'type'})
          t.number(path: 'number', namespace_prefix: 'mods')
          t.caption(path: 'caption', namespace_prefix: 'mods')
        }
        t.extent(path: 'extent', namespace_prefix: 'mods'){
          t.unit(path: { attribute: 'unit' })
          t.start(path: 'start', namespace_prefix: 'mods')
          t.end(path: 'end', namespace_prefix: 'mods')
        }
        t.date(path: 'date', namespace_prefix: 'mods'){
          t.encording(path: { attribute: 'encoding' })
        }
      }
      t.resource_type(path: 'typeOfResource', namespace_prefix: 'mods')
      t.genre(path: 'genre', namespace_prefix: 'mods'){
        t.authority(path: { attribute: 'authority' })
      }
      t.origin_info(path: 'originInfo', namespace_prefix: 'mods'){
        t.place(path: 'place', namespace_prefix: 'mods'){
          t.place_term(path: 'placeTerm', namespace_prefix: 'mods', attributes: { type: 'text' })
        }
        t.publisher(path: 'publisher', namespace_prefix: 'mods', index_as: [:stored_searchable])
        t.issuance(path: 'issuance', namespace_prefix: 'mods')
        t.frequency(path: 'frequency', namespace_prefix: 'mods'){
          t.authority(path: { attribute: 'authority'})
        }
       }
      t.physical_description(path: 'physicalDescription', namespace_prefix: 'mods'){
        t.form(path: 'form', namespace_prefix: 'mods'){
          t.authority(path: { attribute: 'authority'})
        }
        t.digital_origin(path: 'digitalOrigin', namespace_prefix: 'mods')
      }
      t.identifier(path: 'identifier', namespace_prefix: 'mods'){
        t.type(path: { attribute: 'type' })
      }
      t.location(path: 'location', namespace_prefix: 'mods'){
        t.physical_location(path: 'physicalLocation', namespace_prefix: 'mods')
      }
    }

    #custom extension for handling featured content.
    t.extension(path: 'extension', namespace_prefix: 'mods', attributes: { displayLabel: 'scholarly_object'}){
      t.scholarly_object(namespace_prefix: nil){
        t.category(namespace_prefix: nil)
        t.department(namespace_prefix: nil)
        t.degree(namespace_prefix: nil)
        t.course_info(namespace_prefix: nil){
          t.course_number(namespace_prefix: nil)
          t.course_title(namespace_prefix: nil)
        }
      }
    }

    t.topic(proxy: [:subject, :topic])
    t.title(proxy: [:title_info, :title])
    t.non_sort(proxy: [:title_info, :non_sort])
    t.category(ref: [:extension, :scholarly_object, :category])
    t.department(ref: [:extension, :scholarly_object, :department])
    t.degree(ref: [:extension, :scholarly_object, :degree])
    t.course_number(ref: [:extension, :scholarly_object, :course_info, :course_number])
    t.course_title(ref: [:extension, :scholarly_object, :course_info, :course_title])
    t.description(:proxy=>[:abstract])
  end

  def self.xml_template
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.mods('xmlns:drs' => 'https://repository.neu.edu/spec/v1', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd',
                'xmlns:niec' => 'http://repository.neu.edu/schema/niec',
                'xmlns:dcterms' => 'http://purl.org/dc/terms/',
                'xmlns:dwc' => 'http://rs.tdwg.org/dwc/terms/',
                'xmlns:dwr' => 'http://rs.tdwg.org/dwc/xsd/simpledarwincore/'){
        xml.parent.namespace = xml.parent.namespace_definitions.find { |ns| ns.prefix=="mods" }
        xml.titleInfo("usage" => "primary") {
          xml.title
        }
        xml.titleInfo("type" => "alternative"){
          xml.title
        }
        xml.abstract
        xml.name('type' => 'personal')
        xml.name('type' => 'corporate')
        xml.originInfo {
          xml.place{
            xml.placeTerm
          }
          xml.dateCreated('keyDate' => 'yes', 'encoding' => 'w3cdtf')
        }
        xml.language{
          xml.languageTerm
        }
        xml.note('type' => 'citation')
        xml.subject{
          xml.topic ""
        }
        xml.identifier('type' => 'hdl', 'displayLabel' => 'Permanent URL')
        xml.typeOfResource

        xml.recordInfo{
          xml.recordContentSource
          xml.recordOrigin
          xml.descriptionStandard
          xml.languageOfCataloging{
            xml.languageTerm
          }
        }

        xml.physicalDescription{
          xml.form
        }

        # We instantiate all of these fields for every MODS record because terminology
        # generation/access seems to barf without it.
        xml.extension('displayLabel' => 'scholarly_object'){
          xml.scholarly_object{
            xml.parent.namespace = nil

            xml.category{ xml.parent.namespace = nil }
            xml.department{ xml.parent.namespace = nil }
            xml.degree{ xml.parent.namespace = nil }

            xml.course_info{
              xml.parent.namespace = nil
              xml.course_number{  xml.parent.namespace = nil }
              xml.course_title{ xml.parent.namespace = nil }
            }
          }
        }
      }
    end
    builder.doc
  end

  def prefix(path)
    ""
  end

  def method_missing(name, *args, &block)
    result = super

    if result.is_a?(Array) && result.count == 1
      return result.first
    elsif result.is_a?(Array) && result.count == 0
      return ""
    end

    return result
  end

end
