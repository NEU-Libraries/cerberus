class ModsDatastream < ActiveFedora::OmDatastream
  include OM::XML::Document
  include NodeHelper
  include ApplicationHelper

  stored_sortable = Solrizer::Descriptor.new(:string, :stored, :indexed)
  stored_sortable_date = Solrizer::Descriptor.new(:date, :stored, :indexed)

  set_terminology do |t|

    t.root(path: 'mods',
           'xmlns:drs' => 'https://repository.neu.edu/spec/v1',
           'xmlns:mods' => 'http://www.loc.gov/mods/v3',
           'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
           'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd',
           'xmlns:niec' => 'http://repository.neu.edu/schema/niec')

    t.key_date(path: '*', namespace_prefix: 'mods', attributes: { keyDate: "yes" }){
      t.qualifier(path: { attribute: "qualifier" })
    }

    t.title_info(path: 'mods/mods:titleInfo', namespace_prefix: 'mods', attributes: { type: :none }){
      t.title(path: 'title', namespace_prefix: 'mods', index_as: [:stored_searchable, stored_sortable])
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
      t.cartographics(path: 'cartographics', namespace_prefix: 'mods'){
        t.scale(path: 'scale', namespace_prefix: 'mods')
        t.projection(path: 'projection', namespace_prefix: 'mods')
        t.coordinates(path: 'coordinates', namespace_prefix: 'mods')
      }
      t.geographic(path: 'geographic', namespace_prefix: 'mods')
      t.topic(path: 'topic', namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.authority(path: { attribute: 'authority' })
      }
      t.scoped_topic(path: 'topic', namespace_prefix: 'mods', attributes: { authority: :any })
      t.name(path: 'name', namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.type(path: {attribute: 'type'})
        t.name_part(path: 'namePart', namespace_prefix: 'mods', attributes: { type: :none })
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
        t.title(path: 'title', namespace_prefix: 'mods')
        t.non_sort(path: 'nonSort', namespace_prefix: 'mods')
        t.sub_title(path: 'subTitle', namespace_prefix: 'mods')
      }
      t.geographic_code(path: 'geographicCode', namespace_prefix: 'mods'){
        t.authority(path: {attribute: 'authority'})
        t.authority_uri(path: {attribute: 'authorityURI'})
        t.value_uri(path: {attribute: 'valueURI'})
      }
      t.genre(path: 'genre', namespace_prefix: 'mods'){
        t.authority(path: {attribute: 'authority'})
        t.authority_uri(path: {attribute: 'authorityURI'})
        t.value_uri(path: {attribute: 'valueURI'})
      }
    }

    t.identifier(path: 'identifier', namespace_prefix: 'mods', index_as: [:stored_searchable], attributes: { type: 'hdl' }){
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
  end

  include Cerberus::ModsExtensions::NIEC

  # We override to_solr here to add
  # 1. A creation_year field.
  # 2. A valid date Begin field
  # 3. A valid date End field
  # 4. Special facetable keywords, e.g. any subject/topic field with an authority attribute
  def to_solr(solr_doc = Hash.new())
    super(solr_doc) # Run the default solrization behavior

    # Solrize extension information.
    solr_doc["drs_category_ssim"] = self.category.first if !self.category.first.blank?
    solr_doc["drs_department_ssim"] = self.department.first if !self.department.first.blank?
    solr_doc["drs_degree_ssim"] = self.degree.first if !self.degree.first.blank?
    solr_doc["drs_course_number_ssim"] = self.course_number.first if !self.course_number.first.blank?
    solr_doc["drs_course_title_ssim"] = self.course_title.first if !self.course_title.first.blank?

    # Extract a creation year field
    if self.origin_info.date_created.any? && !self.origin_info.date_created.first.blank?
      creation_date = self.origin_info.date_created.first
      solr_doc["creation_year_sim"] = [creation_date[/\d{4}/]]
    elsif self.origin_info.copyright.any? && !self.origin_info.copyright.first.blank?
      creation_date = self.origin_info.copyright.first
      solr_doc["creation_year_sim"] = [creation_date[/\d{4}/]]
      # solr_doc["date_issued_ssim"] = [creation_date]
    elsif self.origin_info.date_issued.any? && !self.origin_info.date_issued.first.blank?
      creation_date = self.origin_info.date_issued.first
      solr_doc["creation_year_sim"] = [creation_date[/\d{4}/]]
    end

    # Ensure title is set to a title actually associated with this core file.
    # Over and over and around we go, patching up this junk forever and ever
    solr_doc["title_info_title_ssi"] = kramdown_parse(self.title_info.title.first)
    solr_doc["title_info_title_tesim"] = kramdown_parse(self.title_info.title.first)

    # Make sure all titles and non_sorts end up in title_tesim
    total_title_array = self.all_titles.non_sort.concat self.all_titles.title
    solr_doc["title_tesim"] = total_title_array.select {|item| kramdown_parse(item) unless item.blank?}

    # Kramdown parse for search purposes - #439
    # title_ssi will only be used for sorting - #766
    solr_doc["title_ssi"] = kramdown_parse(self.title_info.title.first).downcase

    # Full title so the api doesn't have to parse it
    solr_doc["full_title_ssi"] = "#{self.non_sort.first} #{kramdown_parse(self.title_info.title.first)}".strip

    # Sortable for date
    solr_doc["date_ssi"] = self.date

    # Kramdown parse for search purposes - #439
    solr_doc["abstract_tesim"] = kramdown_parse(self.abstract.first)

    # Fixes #836
    solr_doc["subject_tesim"] = self.subject.map do |sub|
      sub.squish
    end

    solr_doc["subject_tesim"] = solr_doc["subject_tesim"] - self.subject

    # Extract special subject/topic fields
    authorized_keywords = []

    (0..self.subject.length).each do |i|
      if self.subject(i).topic.authority.any?
        authorized_keywords << self.subject(i).topic.first
      end
    end

    solr_doc["subject_sim"] = authorized_keywords

    #Extract and solrize names divided into first/last parts
    full_names = []

    (0..self.personal_name.length).each do |i|
      fn = self.personal_name(i).name_part_given
      ln = self.personal_name(i).name_part_family
      full_name = self.personal_name(i).name_part

      if fn.any? && ln.any?
        # Kramdown parse for search purposes - #439
        full_names << kramdown_parse("#{ln.first}, #{fn.first}")
      elsif full_name.any?
        name_array = Namae.parse full_name.first
        name_obj = name_array[0]
        if !name_obj.nil? && !name_obj.given.blank? && !name_obj.family.blank?
          full_names << kramdown_parse("#{name_obj.family}, #{name_obj.given}")
        end
      end
    end

    # Author for Google
    author_full_name = ""

    given = self.author_given
    family = self.author_family
    author_name_part = self.author_name_part

    if given.any? && family.any?
      # Kramdown parse for search purposes - #439
      author_full_name = kramdown_parse("#{family.first}, #{given.first}")
    elsif author_name_part.any?
      name_array = Namae.parse author_name_part.first
      name_obj = name_array[0]
      if !name_obj.nil? && !name_obj.given.blank? && !name_obj.family.blank?
        author_full_name = kramdown_parse("#{name_obj.family}, #{name_obj.given}")
      end
    end

    solr_doc["author_tesi"] = author_full_name

    solr_doc["personal_creators_tesim"] = full_names
    solr_doc["personal_creators_sim"] = full_names

    # Create an aggregate facet field of all creator information
    personal_names = solr_doc["personal_creators_sim"] || []
    corporate_names = solr_doc["corporate_name_name_part_sim"] || []
    names = solr_doc["name_name_part_sim"] || []
    all_names = personal_names + corporate_names + names
    solr_doc["creator_sim"] = all_names
    solr_doc["creator_tesim"] = all_names

    # Creating sortable creator field
    solr_doc["creator_ssi"] = all_names.first

    solr_doc["origin_info_place_tesim"] = self.origin_info.place.place_term

    solr_doc = self.generate_niec_solr_hash(solr_doc)

    #TODO:  Extract dateBegin/dateEnd information ]
    return solr_doc
  end


  def self.xml_template
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.mods('xmlns:drs' => 'https://repository.neu.edu/spec/v1', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd',
                'xmlns:niec' => 'http://repository.neu.edu/schema/niec'){
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
        xml["mods"].extension{
          xml["niec"].niec
        }
      }
    end
    builder.doc
  end

  def title=(title)
    if title.kind_of?(Array)
      title = title[0]
    end
    self.title_info.title = title.gsub(/[\s\b\v]+/, " ")
  end

  def description=(desc)
    if desc.kind_of?(Array)
      desc = desc[0]
    end
    self.abstract = desc.gsub(/[\s\b\v]+/, " ")
  end

  # Consolidating all date options for the edit form
  def date
    if self.origin_info.date_created.any? && !self.origin_info.date_created.first.blank?
      return self.origin_info.date_created.first
    elsif self.origin_info.copyright.any? && !self.origin_info.copyright.first.blank?
      return self.origin_info.copyright.first
    elsif self.origin_info.date_issued.any? && !self.origin_info.date_issued.first.blank?
      return self.origin_info.date_issued.first
    elsif self.origin_info.date_other.any? && !self.origin_info.date_other.first.blank?
      return self.origin_info.date_other.first
    end

    # safety return
    return ""
  end

  def date=(date_val, point=nil)
    self.origin_info.date_created = date_val
    if !point.blank?
      self.origin_info.date_created.point = point
    end
  end

  # Filters out blank entries, builds nodes as required
  def names=(x)
    x = x.select { |name| !name.blank? }

    if x.length < self.name.length
      node_count = self.name.length - x.length
      trim_nodes_from_zero(:name, node_count)
    end

    x.each_with_index do |name, i|
      if self.name[i].nil?
        self.insert_new_node(:name)
      end

      self.name(i).name_part = name
    end
  end

  def genres=(array_of_strings)
    array_of_strings.select!{ |ac| !ac.blank?}
    if self.genre.length > array_of_strings.length
      node_count = self.genre.length - array_of_strings.length
      trim_nodes_from_zero(:genre, node_count)
    end
    array = []
    array_of_strings.each_with_index do |genre, i|
      if self.genre[i].nil?
        self.insert_new_node(:genre)
      end
      array << genre
    end
    self.genre = array if !array.blank?
  end

  def abstracts=(array_of_strings)
    array_of_strings.select!{ |ac| !ac.blank?}
    if self.abstract.length > array_of_strings.length
      node_count = self.abstract.length - array_of_strings.length
      trim_nodes_from_zero(:abstract, node_count)
    end
    array = []
    array_of_strings.each_with_index do |abs, i|
      if self.abstract[i].nil?
        self.insert_new_node(:abstract)
      end
      array << abs
    end
    self.abstract = array if !array.blank?
  end

  # Filters out blank keyword entries
  def topics=(array_of_strings)
    changed = false

    array_of_keywords = array_of_strings.select {|kw| !kw.blank? }

    if array_of_keywords.length == self.subject.topic.length
      array_of_keywords.each_with_index do |kw, i|
        if kw != self.subject.topic[i]
          changed = true
        end
      end
    else
      changed = true
    end

    if !changed
      return
    end

    if array_of_keywords.length < self.subject.topic.length
      node_count = self.subject.topic.length - array_of_keywords.length
      trim_nodes_from_zero(:subject, node_count)
    end

    array_of_keywords.each_with_index do |kw, index|
      if self.subject[index].nil?
        self.insert_new_node(:subject)
      end

      if self.subject(index).topic == []
        self.subject(index).topic = [""]
      end
    end

    self.topic = array_of_keywords.map {|kw| kw.gsub(/[\s\b\v]+/, " ") }
  end

  def name_subjects=(array_of_hashes)
    array_of_hashes.select!{ |ac| !ac.blank? && !ac.values.blank?}
    if self.subject.name.length > 0
      remove_subject_nodes(:name)
    end
    array_of_hashes.each_with_index do |subj, i|
      self.insert_new_node(:subject)
      i = self.subject.length-1 #last one
      self.subject(i).name.type = subj.keys[0].to_s
      self.subject(i).name.name_part = subj.values[0]
    end
  end

  def geog_subjects=(array_of_arrays)
    array_of_arrays.select!{ |ac| !ac.blank?}
    if self.subject.geographic.length > 0
      remove_subject_nodes(:geographic)
    end
    array_of_arrays.each_with_index do |subj, i|
      self.insert_new_node(:subject)
      i = self.subject.length-1 #last one
      self.subject(i).geographic = subj
    end
  end

  def temporal_subjects=(array_of_hashes)
    # [{:dates=>["date","date"], :point=>["string","string"], :qualifier=>"string"}]
    array_of_hashes.select!{ |ac| !ac.blank? && !ac.values.blank?}
    if self.subject.temporal.length > 0
      remove_subject_nodes(:temporal)
    end
    array_of_hashes.each_with_index do |subj, i|
      self.insert_new_node(:subject)
      i = self.subject.length-1 #last one
      self.subject(i).temporal = subj[:dates] unless subj[:dates].blank?
      self.subject(i).temporal.each_with_index do |temp, x|
        if !subj[:point].blank?
          self.subject(i).temporal(x).point = subj[:point][x] unless subj[:point][x].blank?
        end
        self.subject(i).temporal(x).qualifier = subj[:qualifier] unless subj[:qualifier].blank?
      end
    end
  end

  def geo_code_subjects=(array_of_strings)
    array_of_strings.select!{ |ac| !ac.blank?}
    if self.subject.geographic_code.length > 0
      remove_subject_nodes(:geographic_code)
    end
    array_of_strings.each_with_index do |subj, i|
      self.insert_new_node(:subject)
      i = self.subject.length-1 #last one
      self.subject(i).geographic_code = subj
    end
  end

  def genre_subjects=(array_of_strings)
    array_of_strings.select!{ |ac| !ac.blank?}
    if self.subject.genre.length > 0
      remove_subject_nodes(:genre)
    end
    array_of_strings.each_with_index do |subj, i|
      self.insert_new_node(:subject)
      i = self.subject.length-1 #last one
      self.subject(i).genre = subj
    end
  end

  def cartographic_subjects=(array_of_hashes)
    array_of_hashes.select!{ |ac| !ac.blank? && !ac.values.blank?}
    if self.subject.cartographics.length > 0
      remove_subject_nodes(:cartographics)
    end
    array_of_hashes.each_with_index do |subj, i|
      self.insert_new_node(:subject)
      i = self.subject.length-1 #last one
      self.subject(i).cartographics.scale = subj[:scale] unless subj[:scale].blank?
      self.subject(i).cartographics.projection = subj[:projection] unless subj[:projection].blank?
      self.subject(i).cartographics.coordinates = subj[:coordinates] unless subj[:coordinates].blank?
    end
  end

  # Allows for tombstone message
  def access_conditions=(array_of_hashes)
    array_of_access = array_of_hashes.select { |ac| !ac.blank? }

    if array_of_access.length < self.access_condition.length
      node_count = self.access_condition.length - array_of_access.length
      trim_nodes_from_zero(:access_condition, node_count)
    end
    i = 0
    values = []
    array_of_access.each do |hash|
      if self.access_condition[i].nil?
        self.insert_new_node(:access_condition)
      end
      self.access_condition(i).type = hash[:type]
      values << hash[:value]
      i = i+1
    end
    self.access_condition = values
  end

  def remove_suppressed_access
    hash = Hash.new
    self.access_condition.each_with_index do |ac, i|
      type = self.access_condition(i).type[0]
      if type != "suppressed"
        hash["#{type}"] = self.access_condition[i]
      end
    end
    self.access_condition = hash
    i = 0
    hash.each do |key, val|
      self.access_condition(i).type = key
      i = i+1
    end
    return hash
  end

  # Allows for multiple notes to be attached to one mods record
  def notes=(array_of_hashes)
    array_of_hashes = array_of_hashes.select { |ac| !ac.blank? }

    if array_of_hashes.length < self.note.length
      node_count = self.note.length - array_of_hashes.length
      trim_nodes_from_zero(:note, node_count)
    end
    i = 0
    notes = []
    array_of_hashes.each_with_index do |hash, i|
      if self.note[i].nil?
        self.insert_new_node(:note)
      end
      self.note(i).type = hash[:type]
      notes << hash[:note]
      i = i+1
    end
    self.note = notes if !notes.blank?
  end

  # Allows for multiple related items to be attached to one mods record
  def related_items=(hash_of_hashes)
    hash_of_items = hash_of_hashes.select { |ac| !ac.blank? }

    if hash_of_items.length < self.related_item.length
      node_count = self.related_item.length - hash_of_items.length
      trim_nodes_from_zero(:related_item, node_count)
    end
    i = 0
    hash_of_items.each do |key, val|
      if self.related_item[i].nil?
        self.insert_new_node(:related_item)
      end
      self.related_item(i).type = key
      # take hash and assign its values
      if val.has_key?(:title)
        self.related_item(i).title_info.title = val[:title]
      end
      if val.has_key?(:physical_location)
        self.related_item(i).location.physical_location = val[:physical_location]
      end
      if val.has_key?(:identifier)
        self.related_item(i).identifier = val[:identifier]
      end
      i = i+1
    end
  end

  def languages=(array_of_strings)
    array_of_langs = array_of_strings.select {|kw| !kw.blank? }
    if array_of_langs.length < self.language.length
      node_count = self.language.length - array_of_langs.length
      trim_nodes_from_zero(:language, node_count)
    end
    i = 0
    array_of_langs.each_with_index do |key, val|
      if self.language[i].nil?
        self.insert_new_node(:language)
      end
      self.language(i).language_term = key
      i = i+1
    end
  end

  def alternate_titles=(array_of_hashes)
    hash_of_titles = array_of_hashes.select { |ac| !ac.blank? }
    if hash_of_titles.length < self.alternate_title.length
      node_count = self.alternate_title.length - hash_of_titles.length
      trim_nodes_from_zero(:alternate_title, node_count)
    end
    i = 0
    hash_of_titles.each do |hash|
      if self.alternate_title[i].nil?
        self.insert_new_node(:alternate_title)
      end
      self.alternate_title(i).non_sort = hash[:non_sort] unless hash[:non_sort].blank?
      self.alternate_title(i).title = hash[:title]
      self.alternate_title(i).sub_title = hash[:sub_title] unless hash[:sub_title].blank?
      self.alternate_title(i).part_name = hash[:part_name] unless hash[:part_name].blank?
      self.alternate_title(i).part_name = hash[:part_number] unless hash[:part_number].blank?
      i = i+1
    end
  end

  def title_subjects=(array_of_hashes)
    array_of_hashes.select { |ac| !ac.blank? && !ac.values.blank?}
    if self.subject.title_info.length > 0
      remove_subject_nodes(:title_info)
    end
    array_of_hashes.each do |hash, i|
      if !hash[:title].blank?
        self.insert_new_node(:subject)
        i = self.subject.length-1
        self.subject(i).title_info.non_sort = hash[:non_sort] unless hash[:non_sort].blank?
        self.subject(i).title_info.title = hash[:title] unless hash[:title].blank?
        self.subject(i).title_info.type = hash[:type] unless hash[:type].blank?
        self.subject(i).title_info.sub_title = hash[:sub_title] unless hash[:sub_title].blank?
      end
      i = i+1
    end
  end

  def personal_creators=(personal_creators_hash)
    first_names = personal_creators_hash['first_names']
    last_names = personal_creators_hash['last_names']
    name_pairs = Hash[first_names.zip(last_names)]

    if personal_creators_hash.length > 0
      name_pairs.each_with_index do |(first_name, last_name), index|
        if self.personal_name[index].nil?
          self.insert_new_node(:personal_name)
        end

        self.personal_name(index).name_part_given = first_name.gsub(/[\s\b\v]+/, " ")
        self.personal_name(index).name_part_family = last_name.gsub(/[\s\b\v]+/, " ")
        self.personal_name(index).name_part = ""
      end
    end
  end

  # The following four methods are probably deprecated, given that we won't be
  # collecting corporate/personal names separately from end users, and therefore shouldn't
  # have to assign to it/read from it for the purposes of the frontend.

  # Takes two arrays of equal length and turns them into correctly formatted
  # mods_personal_name nodes.
  def assign_creator_personal_names(first_names, last_names)

    # Check if names have changed - if not, we do nothing to avoid muddling hand-made MODS XML
    existing_names = self.personal_creators
    existing_first_names = []
    existing_last_names = []
    changed = false

    existing_names.each do |hsh|
      hsh.each do |key, val|
        if key == :first
          existing_first_names << val
        elsif key == :last
          existing_last_names << val
        end
      end
    end

    if existing_first_names != first_names
      changed = true
    end
    if existing_last_names != last_names
      changed = true
    end

    if !changed
      # No changes, so let's not unnecessarily muddle hand made MODS
      return
    end

    if first_names.length != last_names.length
      raise "#{first_names.length} first names received and #{last_names.length} last names received, which won't do at all."
    end

    name_pairs = Hash[first_names.zip(last_names)]

    name_pairs.select! { |first, last| !first.blank? && !last.blank? }

    if name_pairs.length < self.personal_name.length
      node_count = self.personal_name.length - name_pairs.length
      trim_nodes_from_zero(:personal_name, node_count)
    end

    if name_pairs.length > 0
      name_pairs.each_with_index do |(first_name, last_name), index|
        if self.personal_name[index].nil?
          self.insert_new_node(:personal_name)
        end

        self.personal_name(index).name_part_given = first_name.gsub(/[\s\b\v]+/, " ")
        self.personal_name(index).name_part_family = last_name.gsub(/[\s\b\v]+/, " ")
        self.personal_name(index).name_part = ""
      end

      # Set usage attribute to primary
      self.personal_name(0).usage = "primary"
      if !self.corporate_name(0).first.blank?
        # Set usage attribute to blank
        self.corporate_name(0).usage = nil
      end
    end
  end

  # Takes an array and turns it into correctly formatted mods_corporate_name nodes.
  def assign_corporate_names(cns)

    cns.select! { |name| !name.blank? }

    if cns.length < self.corporate_name.length
      node_count = self.corporate_name.length - cns.length
      trim_nodes_from_zero(:corporate_name, node_count)
    end

    if cns.length > 0
      cns.each_with_index do |c_name, index|
        if self.corporate_name[index].nil?
          self.insert_new_node(:corporate_name)
        end

        self.corporate_name(index).name_part = c_name.gsub(/[\s\b\v]+/, " ")
      end

      # Set usage attribute to primary
      if self.personal_name(0).first.blank?
        self.corporate_name(0).usage = "primary"
        # Set usage attribute to blank
        self.personal_name(0).usage = nil
      end
    end
  end

  # Eliminates some whitespace that seems to get inserted into these records when they're
  # returned.
  def corporate_creators
    no_newlines = self.corporate_name.map { |name| name.delete("\n") }
    trimmed = no_newlines.map { |name| name.strip }
    return trimmed
  end

  # Formats the otherwise messy return for personal creator information
  def personal_creators

    result_array = []
    first_names = []
    last_names = []

    for i in (0..(self.personal_name.length - 1))
      fn = self.personal_name(i).name_part_given
      ln = self.personal_name(i).name_part_family
      full_name = self.personal_name(i).name_part

      if !full_name.blank? && full_name.first.length > 0 && fn.blank? && ln.blank?
        name_array = Namae.parse full_name.first
        name_obj = name_array[0]
        if !name_obj.nil? && !name_obj.given.blank? && !name_obj.family.blank?
          first_names << name_obj.given
          last_names << name_obj.family
        end
      end
    end

    result_array = []

    first_names.concat self.personal_name.name_part_given
    last_names.concat self.personal_name.name_part_family

    names = first_names.zip(last_names)

    # NB: When accessing nested arrays of form [[first, second], [first, second]]
    # that are all of even length, array.each do |first, second| grabs both elements
    # out of each nested array in sequence.  Did not know this until I looked it up.
    names.each do |first, last|
      result_array << Hash[first: first, last: last]
    end

    return result_array
  end



  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Template files used by NodeHelper to add/remove nodes
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  def self.name_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.name
    end
    return builder.doc.root
  end

  def self.subject_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.subject{
      }
    end
    return builder.doc.root
  end

  def self.personal_name_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.name('type' => 'personal')
    end
    return builder.doc.root
  end

  def self.corporate_name_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.name('type' => 'corporate')
    end
    return builder.doc.root
  end

  def self.name_part_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.namePart " "
    end
    return builder.doc.root
  end

  def self.access_condition_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.accessCondition " "
    end
    return builder.doc.root
  end

  def self.note_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.note " "
    end
    return builder.doc.root
  end

  def self.related_item_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.relatedItem{
        xml.titleInfo{
          xml.title " "
        }
      }
    end
    return builder.doc.root
  end

  def self.topic_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.topic " "
    end
    return builder.doc.root
  end

  def self.language_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.language {
      }
    end
    return builder.doc.root
  end

  def self.alternate_title_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.titleInfo('type' => 'alternative') {
      }
    end
    return builder.doc.root
  end

  def self.abstract_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.abstract " "
    end
    return builder.doc.root
  end

  def self.genre_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.genre " "
    end
    return builder.doc.root
  end
end
