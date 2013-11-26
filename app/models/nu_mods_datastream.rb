class NuModsDatastream < ActiveFedora::OmDatastream 
  include OM::XML::Document
  include NodeHelper  

  stored_sortable = Solrizer::Descriptor.new(:string, :stored, :indexed)
  stored_sortable_date = Solrizer::Descriptor.new(:date, :stored, :indexed)

  set_terminology do |t|

    t.root(path: 'mods', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd')
    t.title_info(path: 'titleInfo', namespace_prefix: 'mods'){
      t.title(path: 'title', namespace_prefix: 'mods', index_as: [:stored_searchable, stored_sortable]) 
      t.sub_title(path: 'subTitle', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.part_name(path: 'partName', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.part_number(path: 'partNumber', namespace_prefix: 'mods', index_as: [:stored_searchable])
    }

    t.abstract(path: 'abstract', namespace_prefix: 'mods', index_as: [:stored_searchable])

    t.name(path: 'name', namespace_prefix: 'mods'){
      t.name_part(path: 'namePart', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable])
    }

    t.personal_name(path: 'name', namespace_prefix: 'mods', attributes: { type: 'personal' }){
      t.authority(path: { attribute: 'authority' })
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

    t.mods_type_of_resource(path: 'typeOfResource', namespace_prefix: 'mods')

    t.mods_genre(path: 'genre', namespace_prefix: 'mods', index_as: [:stored_searchable, :facetable, :symbol]){
      t.mods_genre_authority(path: { attribute: 'authority' })
    }

    t.mods_origin_info(path: 'originInfo', namespace_prefix: 'mods'){
      t.mods_publisher(path: 'publisher', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.mods_place(path: 'place', namespace_prefix: 'mods', index_as: [:stored_searchable])
      t.mods_copyright(path: 'copyrightDate', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf' })
      t.mods_date_issued(path: 'dateIssued', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf', keyDate: 'yes' })
      t.mods_date_other(path: 'dateOther', namespace_prefix: 'mods', index_as: [:stored_searchable], attributes: { encoding: 'w3cdtf'})
      t.mods_issuance(path: 'issuance', namespace_prefix: 'mods')
    }

    t.mods_language(path: 'language', namespace_prefix: 'mods'){
      t.mods_language_term(path: 'languageTerm', namespace_prefix: 'mods'){
        t.mods_language_term_type(path: { attribute: 'type'})
        t.mods_language_authority(path: { attribute: 'authority'})
      }
    }

    t.mods_physical_description(path: 'physicalDescription', namespace_prefix: 'mods'){
      t.form(path: 'form', namespace_prefix: 'mods'){
        t.authority(path: {attribute: 'authority'})
      }
      t.digital_origin(path: 'digitalOrigin')
    }

    t.mods_note(path: 'note', namespace_prefix: 'mods', index_as: [:stored_searchable]){
      t.type(path: { attribute: 'type' })
    }

    t.mods_subject(path: 'subject', namespace_prefix: 'mods'){
      t.mods_keyword(path: 'topic', namespace_prefix: 'mods', index_as: [:stored_searchable]){
        t.authority(path: { attribute: 'authority' })
      }
    }
    t.mods_identifier(path: 'identifier', namespace_prefix: 'mods', index_as: [:stored_searchable]){
      t.mods_identifier_type(path: { attribute: 'type'})
    }

    t.mods_related_item(path: 'relatedItem', namespace_prefix: 'mods'){
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

    t.title(proxy: [:title_info, :title])
    t.mods_date_issued(proxy: [:mods_origin_info, :mods_date_issued]) 
  end

  # We override to_solr here to add 
  # 1. A creation_year field. 
  # 2. A valid date Begin field 
  # 3. A valid date End field 
  # 4. Special facetable keywords, e.g. any subject/topic field with an authority attribute
  def to_solr(solr_doc = Hash.new()) 
    super(solr_doc) # Run the default solrization behavior 

    # Extract a creation year field
    if self.mods_origin_info.mods_date_issued.any?
      creation_date = self.mods_origin_info.mods_date_issued.first 
      solr_doc["mods_creation_year_sim"] = [creation_date[/\d{4}/]]
    end

    # Extract special subject/topic fields
    authorized_keywords = []

    (0..self.mods_subject.length).each do |i|
      if self.mods_subject(i).mods_keyword.authority.any?
        authorized_keywords << mods_subject(i).mods_keyword.first
      end
    end

    solr_doc["mods_keyword_sim"] = authorized_keywords 

    #Extract and solrize names divided into first/last parts
    full_names = []

    (0..self.personal_name.length).each do |i| 
      fn = self.personal_name(i).name_part_given 
      ln = self.personal_name(i).name_part_family

      if fn.any? && ln.any?
        full_names << "#{fn.first} #{ln.first}"
      end
    end

    solr_doc["personal_creators_tesim"] = full_names
    solr_doc["personal_creators_sim"] = full_names

    #TODO:  Extract dateBegin/dateEnd information ]
    return solr_doc
  end


  def self.xml_template 
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.mods('xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
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
      }
    end
    builder.doc
  end

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

  # Custom setters for fields that require some extra sanitization

  # Filters out blank keyword entries 
  def keywords=(array_of_strings) 
    array_of_keywords = array_of_strings.select {|kw| !kw.blank? }  
    
    if array_of_keywords.length < self.mods_subject.length 
      node_count = self.mods_subject.length - array_of_keywords.length 
      trim_nodes_from_zero(:mods_subject)
    end

    array_of_keywords.each_with_index do |kw, index| 
      if self.mods_subject[index].nil? 
        self.insert_new_node(:mods_subject) 
      end

      self.mods_subject(index).mods_keyword = kw 
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

  def self.mods_subject_template 
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