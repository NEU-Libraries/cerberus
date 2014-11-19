class ModsDatastream < ActiveFedora::OmDatastream
  include OM::XML::Document
  include NodeHelper
  include ApplicationHelper

  stored_sortable = Solrizer::Descriptor.new(:string, :stored, :indexed)
  stored_sortable_date = Solrizer::Descriptor.new(:date, :stored, :indexed)

  set_terminology do |t|

    t.root(path: 'mods', 'xmlns:drs' => 'https://repository.neu.edu/spec/v1', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd')
    t.title_info(path: 'titleInfo', namespace_prefix: 'mods'){
      t.title(path: 'title', namespace_prefix: 'mods', index_as: [:stored_searchable, stored_sortable])
      t.non_sort(path: 'nonSort', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.sub_title(path: 'subTitle', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.part_name(path: 'partName', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.part_number(path: 'partNumber', namespace_prefix: 'mods', index_as: [:stored_searchable])
    }

    t.abstract(path: 'abstract', namespace_prefix: 'mods', index_as: [:stored_searchable])

    t.name(path: 'name', namespace_prefix: 'mods', attributes: { type: :none }){
      t.name_part(path: 'namePart', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
    }

    t.personal_name(path: 'name', namespace_prefix: 'mods', attributes: { type: 'personal' }){
      t.authority(path: { attribute: 'authority' })
      t.name_part(path: 'namePart', namespace_prefix: 'mods', attributes: { type: :none }, index_as: [:stored_searchable, :facetable])
      t.name_part_given(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'given' })
      t.name_part_family(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'family' })
      t.role(namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.role_term(path: 'roleTerm', namespace_prefix: 'mods'){
          t.authority(path: { attribute: 'authority'})
          t.type(path: { attribute: 'type'})
        }
      }
    }

    t.corporate_name(path: 'name', namespace_prefix: 'mods', attributes: { type: 'corporate' }){
      t.name_part(path: 'namePart', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
    }

    t.type_of_resource(path: 'typeOfResource', namespace_prefix: 'mods')

    t.genre(path: 'genre', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable]){
      t.authority(path: { attribute: 'authority' })
    }

    t.origin_info(path: 'originInfo', namespace_prefix: 'mods'){
      t.publisher(path: 'publisher', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.place(path: 'place', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.date_created(path: 'dateCreated', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable], attributes: { encoding: 'w3cdtf', keyDate: 'yes' })
      t.copyright(path: 'copyrightDate', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable], attributes: { encoding: 'w3cdtf' })
      t.date_issued(path: 'dateIssued', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable], attributes: { encoding: 'w3cdtf' })
      t.date_other(path: 'dateOther', namespace_prefix: 'mods', index_as: [:stored_searchable], attributes: { encoding: 'w3cdtf'})
      t.issuance(path: 'issuance', namespace_prefix: 'mods')
    }

    t.language(path: 'language', namespace_prefix: 'mods'){
      t.language_term(path: 'languageTerm', namespace_prefix: 'mods'){
        t.language_term_type(path: { attribute: 'type'})
        t.language_authority(path: { attribute: 'authority'})
      }
    }

    t.physical_description(path: 'physicalDescription', namespace_prefix: 'mods'){
      t.form(path: 'form', namespace_prefix: 'mods'){
        t.authority(path: {attribute: 'authority'})
      }
      t.digital_origin(path: 'digitalOrigin')
    }

    t.note(path: 'note', namespace_prefix: 'mods', index_as: [:stored_searchable]){
      t.type(path: { attribute: 'type' })
    }

    t.subject(path: 'subject', namespace_prefix: 'mods'){
      t.topic(path: 'topic', namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.authority(path: { attribute: 'authority' })
      }
      t.scoped_topic(path: 'topic', namespace_prefix: 'mods', attributes: { authority: :any })
    }
    t.identifier(path: 'identifier', namespace_prefix: 'mods', index_as: [:stored_searchable]){
      t.type(path: { attribute: 'type'})
    }

    t.related_item(path: 'relatedItem', namespace_prefix: 'mods'){
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
          t.term(path: 'placeTerm', namespace_prefix: 'mods'){
            t.type(path: { attribute: 'type' })
          }
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

    t.title(proxy: [:title_info, :title])
    t.date_issued(proxy: [:origin_info, :date_issued])
    t.category(ref: [:extension, :scholarly_object, :category])
    t.department(ref: [:extension, :scholarly_object, :department])
    t.degree(ref: [:extension, :scholarly_object, :degree])
    t.course_number(ref: [:extension, :scholarly_object, :course_info, :course_number])
    t.course_title(ref: [:extension, :scholarly_object, :course_info, :course_title])
  end

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
    if self.origin_info.copyright.any? && !self.origin_info.copyright.first.blank?
      creation_date = self.origin_info.copyright.first
      solr_doc["creation_year_sim"] = [creation_date[/\d{4}/]]
      # solr_doc["date_issued_ssim"] = [creation_date]
    elsif self.origin_info.date_issued.any? && !self.origin_info.date_issued.first.blank?
      creation_date = self.origin_info.date_issued.first
      solr_doc["creation_year_sim"] = [creation_date[/\d{4}/]]
    end

    # Ensure title is set to a title actually associated with this core file.
    solr_doc["title_info_title_ssi"] = self.title_info.title.first

    # Kramdown parse for search purposes - #439
    solr_doc["title_ssi"] = kramdown_parse(self.title_info.title.first)

    # Kramdown parse for search purposes - #439
    solr_doc["abstract_tesim"] = kramdown_parse(self.abstract.first)

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

      if fn.any? && ln.any?
        # Kramdown parse for search purposes - #439
        full_names << kramdown_parse("#{ln.first}, #{fn.first}")
      end
    end

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

    #TODO:  Extract dateBegin/dateEnd information ]
    return solr_doc
  end


  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.mods('xmlns:drs' => 'https://repository.neu.edu/spec/v1', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd'){
        xml.parent.namespace = xml.parent.namespace_definitions.find { |ns| ns.prefix=="mods" }
        xml.titleInfo {
          xml.title
        }
        xml.abstract
        xml.name('type' => 'personal')
        xml.name('type' => 'corporate')
        xml.originInfo {
          xml.dateIssued('keyDate' => 'yes', 'encoding' => 'w3cdtf')
        }
        xml.language{
          xml.languageTerm
        }
        xml.note('type' => 'citation')
        xml.subject
        xml.identifier
        xml.typeOfResource

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

  # Filters out blank keyword entries
  def topics=(array_of_strings)
    array_of_keywords = array_of_strings.select {|kw| !kw.blank? }

    if array_of_keywords.length < self.subject.length
      node_count = self.subject.length - array_of_keywords.length
      trim_nodes_from_zero(:subject, node_count)
    end

    array_of_keywords.each_with_index do |kw, index|
      if self.subject[index].nil?
        self.insert_new_node(:subject)
      end

      self.subject(index).topic = kw
    end
  end

  # The following four methods are probably deprecated, given that we won't be
  # collecting corporate/personal names separately from end users, and therefore shouldn't
  # have to assign to it/read from it for the purposes of the frontend.

  # Takes two arrays of equal length and turns them into correctly formatted
  # mods_personal_name nodes.
  def assign_creator_personal_names(first_names, last_names)
    if first_names.length != last_names.length
      raise "#{first_names.length} first names received and #{last_names.length} last names received, which won't do at all."
    end

    name_pairs = Hash[first_names.zip(last_names)]

    name_pairs.select! { |first, last| !first.blank? && !last.blank? }

    if name_pairs.length < self.personal_name.length
      node_count = self.personal_name.length - name_pairs.length
      trim_nodes_from_zero(:personal_name, node_count)
    end

    name_pairs.each_with_index do |(first_name, last_name), index|
      if self.personal_name[index].nil?
        self.insert_new_node(:personal_name)
      end

      self.personal_name(index).name_part_given = first_name
      self.personal_name(index).name_part_family = last_name
    end
  end

  # Takes an array and turns it into correctly formatted mods_corporate_name nodes.
  def assign_corporate_names(cns)

    cns.select! { |name| !name.blank? }

    if cns.length < self.corporate_name.length
      node_count = self.corporate_name.length - cns.length
      trim_nodes_from_zero(:corporate_name, node_count)
    end

    cns.each_with_index do |c_name, index|
      if self.corporate_name[index].nil?
        self.insert_new_node(:corporate_name)
      end

      self.corporate_name(index).name_part = c_name
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

    first_names = self.personal_name.name_part_given
    last_names = self.personal_name.name_part_family

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
      xml.subject
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
end
