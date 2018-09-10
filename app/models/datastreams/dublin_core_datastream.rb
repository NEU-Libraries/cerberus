class DublinCoreDatastream < ActiveFedora::OmDatastream
  include OM::XML::Document
  include ActiveModel::Validations
  include NodeHelper

  set_terminology do |t|
    t.root(path: 'dc', namespace_prefix: 'oai_dc', 'xmlns:oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/', 'xmlns:dc' => 'http://purl.org/dc/elements/1.1/', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd')
    t.nu_title(path: 'title', namespace_prefix: 'dc')
    t.nu_description(path: 'description', namespace_prefix: 'dc')
    t.nu_type(path: 'type', namespace_prefix: 'dc')
    t.nu_identifier(path: 'identifier', namespace_prefix: 'dc')
    t.date(namespace_prefix: 'dc')
    t.creator(namespace_prefix: 'dc')
    t.subject(namespace_prefix: 'dc')
  end

  def to_solr(solr_doc = Hash.new)
    super(solr_doc)

    accepted_list = ["Collection", "Dataset", "Event", "Image", "InteractiveResource", "MovingImage", "PhysicalObject", "Service", "Software", "Sound", "StillImage", "Text"]

    solr_doc["type_sim"] = self.nu_type.first unless self.nu_type.first.blank?

    return solr_doc
  end


  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml['oai_dc'].dc('xmlns:oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/', 'xmlns:dc' => 'http://purl.org/dc/elements/1.1/', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                    'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd'){
        xml['dc'].title
        xml['dc'].creator
        xml['dc'].date
        xml['dc'].description
        xml['dc'].type
        xml['dc'].subject
        xml['dc'].identifier
      }
    end
    builder.doc
  end

  # With no method of distinguishing between corporate and personal creators,
  # we have to collapse assignment of all creators into a single method to avoid
  # unintentional overwrites.  This is not ideal.
  def assign_creators(first_names, last_names, corporate_creators)
    pns = construct_personal_names(first_names, last_names)

    all_names = pns + corporate_creators

    self.creator = all_names
  end


  # Individual contributors/creators will typically be identified by first/last name.
  # This method takes two arrays of equal length and creates personal names with them.
  def construct_personal_names(first_names, last_names)

    if first_names.length != last_names.length
      raise "Passed #{first_names.length} first names and #{last_names.length} last names."
    end

    full_names = []
    first_names.each_with_index do |fn, i|
     full_names << "#{fn} #{last_names[i]}"
    end

    return full_names
  end
end
