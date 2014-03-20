# employee datastream: persistence for nuid and name, allowing us to index with solr
class DrsEmployeeDatastream < ActiveFedora::OmDatastream
  set_terminology do |t|
    t.root(:path=>"fields" )
    t.nuid :index_as=>[:stored_searchable]
    t.name
    t.status
  end

  def to_solr(solr_doc = Hash.new)
    super(solr_doc)

    solr_doc["employee_name_tesim"] = self.name.first if self.name.first
    solr_doc["employee_nuid_ssim"] = self.nuid.first if self.nuid.first

    return solr_doc
  end

  def employee_is_building
    self.status = "BUILDING"
  end

  def employee_is_complete
    self.status = "COMPLETE"
  end

  def is_building?
    return self.status.first == "BUILDING"
  end

  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.fields
    end
    builder.doc
  end
end
