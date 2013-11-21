class NuModsDatastream < ActiveFedora::OmDatastream 
  include OM::XML::Document
  include NodeHelper  

  set_terminology do |t|
    t.root(path: 'mods', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd')
    t.mods_title_info(path: 'titleInfo', namespace_prefix: 'mods'){
      t.mods_title(path: 'title', namespace_prefix: 'mods') 
    }

    t.mods_abstract(path: 'abstract', namespace_prefix: 'mods')

    t.mods_personal_name(path: 'name', namespace_prefix: 'mods', attributes: { type: 'personal' }){
      t.mods_first_name(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'given' }) 
      t.mods_last_name(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'family' }) 
    }

    t.mods_corporate_name(path: 'name', namespace_prefix: 'mods', attributes: { type: 'corporate' }){
      t.mods_full_corporate_name(path: 'namePart', namespace_prefix: 'mods')  
    }

    t.mods_type_of_resource(path: 'typeOfResource', namespace_prefix: 'mods')

    t.mods_genre(path: 'genre', namespace_prefix: 'mods'){
      t.mods_genre_authority(path: { attribute: 'authority' })
    }

    t.mods_origin_info(path: 'originInfo', namespace_prefix: 'mods'){
      t.mods_publisher(path: 'publisher', namespace_prefix: 'mods')
      t.mods_copyright(path: 'copyrightDate', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf' })
      t.mods_date_issued(path: 'dateIssued', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf', keyDate: 'yes' })
      t.mods_date_other(path: 'dateOther', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf'})
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

    t.mods_citation(path: 'note', namespace_prefix: 'mods', attributes: { type: 'citation' }) 

    t.mods_subject(path: 'subject', namespace_prefix: 'mods'){
      t.mods_keyword(path: 'topic', namespace_prefix: 'mods') 
    }
    t.mods_identifier(path: 'identifier', namespace_prefix: 'mods'){
      t.mods_identifier_type(path: { attribute: 'type'})
    }

    t.mods_title(proxy: [:mods_title_info, :mods_title])
    t.mods_date_issued(proxy: [:mods_origin_info, :mods_date_issued]) 
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

    if name_pairs.length < self.mods_personal_name.length
      node_count = self.mods_personal_name.length - name_pairs.length
      trim_nodes_from_zero(:mods_personal_name, node_count)
    end

    name_pairs.each_with_index do |(first_name, last_name), index|
      if self.mods_personal_name[index].nil? 
        self.insert_new_node(:mods_personal_name) 
      end

      self.mods_personal_name(index).mods_first_name = first_name 
      self.mods_personal_name(index).mods_last_name = last_name 
    end
  end

  # Takes an array and turns it into correctly formatted mods_corporate_name nodes. 
  def assign_corporate_names(corporate_names)

    corporate_names.select! { |name| !name.blank? } 

    if corporate_names.length < self.mods_corporate_name.length 
      node_count = self.mods_corporate_name.length - corporate_names.length 
      trim_nodes_from_zero(:mods_corporate_name, node_count) 
    end

    corporate_names.each_with_index do |c_name, index|
      if self.mods_corporate_name[index].nil? 
        self.insert_new_node(:mods_corporate_name) 
      end

      self.mods_corporate_name(index).mods_full_corporate_name = c_name 
    end
  end

  # Custom setters for fields that require some extra sanitization

  # Filters out blank keyword entries 
  def keywords=(array_of_strings) 
    array_of_keywords = array_of_strings.select {|kw| !kw.blank? }  
    self.mods_subject(0).mods_keyword = array_of_keywords
  end 

  # Eliminates some whitespace that seems to get inserted into these records when they're 
  # returned. 
  def corporate_creators
    no_newlines = self.mods_corporate_name.map { |name| name.delete("\n") }
    trimmed = no_newlines.map { |name| name.strip }  
    return trimmed
  end

  # Formats the otherwise messy return for personal creator information 
  def personal_creators 
    result_array = []

    first_names = self.mods_personal_name.mods_first_name 
    last_names = self.mods_personal_name.mods_last_name 

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

  def self.mods_personal_name_template 
    builder = Nokogiri::XML::Builder.new do |xml| 
      xml.name('type' => 'personal') 
    end
    return builder.doc.root 
  end

  def self.mods_corporate_name_template 
    builder = Nokogiri::XML::Builder.new do |xml| 
      xml.name('type' => 'corporate') 
    end
    return builder.doc.root 
  end
end