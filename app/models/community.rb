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

  def theses
    child_collections.find { |e| e.smart_collection_type == 'Theses and Dissertations' }
  end

  def research_publications
    employee_query(:all_research_publications)
  end

  def other_publications
    employee_query(:all_other_publications)
  end

  def data_sets
    employee_query(:all_data_sets)
  end

  def presentations
    employee_query(:all_presentations)
  end

  def learning_objects
    employee_query(:all_learning_objects)
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

  private

    def employee_query(sym)
      self.employees.inject([]) { |b, emp| b + emp.public_send(sym) }
    end
end
