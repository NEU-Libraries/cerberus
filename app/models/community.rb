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
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream
  has_file_datastream "thumbnail", type: FileContentDatastream

  attr_accessible :title, :description, :parent
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

  private 

    def employee_query(sym) 
      self.employees.inject([]) { |b, emp| b + emp.public_send(sym) } 
    end
end