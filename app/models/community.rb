class Community < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  include Hydra::ModelMixins::RightsMetadata
  include Hydra::ModelMethods
  include Drs::Rights::MassPermissions
  include Drs::Rights::Embargoable
  include Drs::Rights::InheritedRestrictions
  include Drs::MetadataAssignment
  include Drs::Relationships
  include Drs::Find

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'mods', type: NuModsDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream

  has_file_datastream "thumbnail", type: FileContentDatastream

  attr_accessible :title, :description, :parent
  attr_accessor :theses
  attr_protected :identifier

  has_many :employees, property: :has_affiliation, class_name: "Employee"
  has_many :child_collections, property: :is_member_of, :class_name => "NuCollection"
  has_many :child_communities, property: :has_affiliation, :class_name => "Community"

  belongs_to :parent, property: :has_affiliation, :class_name => "Community"

  # Depth first(ish) traversal of a graph.
  def each_depth_first
    combinedChildren = self.child_collections + self.child_communities

    combinedChildren.each do |child|
      child.each_depth_first do |c|
        yield c
      end
    end

    yield self
  end

  # Override parent= so that the string passed by the creation form can be used.
  def parent=(val)
    unique_assign_by_string(val, :has_affiliation, [Community], allow_nil: true)
    self.properties.parent_id = val
  end

  def full_self_id
    full_self_id = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{self.pid}"
  end

  def find_employees
    employee_model = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Employee"
    query_result = ActiveFedora::SolrService.query("has_affiliation_ssim:\"#{self.full_self_id}\" AND has_model_ssim:\"#{employee_model}\"")
    query_result.map { |x| SolrDocument.new(x) }
  end

  def find_user_root_collections
    doc_list ||= []
    employee_list = find_employees
    employee_list.each do |e|
      full_employee_id = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{e.pid}"
      query_result = ActiveFedora::SolrService.query("is_member_of_ssim:\"#{full_employee_id}\" AND smart_collection_type_tesim:\"User Root\"")
      doc_list << query_result.map { |x| SolrDocument.new(x) }
    end
    return doc_list
  end

  def find_smart_collections_by_type(type_str)
    doc_list ||= []
    user_root_list = find_user_root_collections
    user_root_list.each do |r|
      query_result = ActiveFedora::SolrService.query("parent_id_tesim:\"#{r.first.pid}\" AND smart_collection_type_tesim:\"#{type_str}\"")
      doc_list << query_result.map { |x| SolrDocument.new(x) }
    end
    return doc_list
  end

  def find_all_files_by_type(type_str)
    doc_list ||= []
    cols = find_smart_collections_by_type(type_str)
    cols.each do |c|
      doc_list << c.first.all_descendent_files
    end
    return doc_list
  end

  def theses
    child_collections.find { |e| e.smart_collection_type == 'Theses and Dissertations' }
  end

  def research_publications
    find_all_files_by_type("Research Publications")
  end

  def other_publications
    find_all_files_by_type("Other Publications")
  end

  def data_sets
    find_all_files_by_type("Datasets")
  end

  def presentations
    find_all_files_by_type("Presentations")
  end

  def learning_objects
    find_all_files_by_type("Learning Objects")
  end

  def smart_collections
    smart_collection_list ||= []
    if self.research_publications.length > 0
      smart_collection_list << "research"
    elsif self.data_sets.length > 0
      smart_collection_list << "datasets"
    elsif self.presentations.length > 0
      smart_collection_list << "presentations"
    elsif self.learning_objects.length > 0
      smart_collection_list << "learning"
    elsif self.other_publications.length > 0
      smart_collection_list << "other"
    end
    return smart_collection_list
  end


  # Simple human readable label for objects.
  def type_label
    "Community"
  end

end
