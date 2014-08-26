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

  has_metadata name: 'DC', type: DublinCoreDatastream
  has_metadata name: 'mods', type: NuModsDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: PropertiesDatastream

  has_file_datastream "thumbnail_1", type: FileContentDatastream
  has_file_datastream "thumbnail_2", type: FileContentDatastream
  has_file_datastream "thumbnail_3", type: FileContentDatastream

  attr_accessible :title, :description, :parent
  attr_accessor :theses
  attr_protected :identifier

  has_many :employees, property: :has_affiliation, class_name: "Employee"
  has_many :child_collections, property: :is_member_of, :class_name => "Collection"
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

end
