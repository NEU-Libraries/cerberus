class NuCollection < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  include Hydra::ModelMixins::RightsMetadata
  include Hydra::ModelMethods
  include Drs::Rights::MassPermissions
  include Drs::Rights::Embargoable
  include Drs::Rights::InheritedRestrictions
  include Drs::Rights::PermissionsAssignmentHelper
  include Drs::MetadataAssignment
  include Drs::Relationships
  include Drs::Find

  validate :belong_check, on: :update

  attr_accessible :title, :description, :date_of_issue, :keywords, :parent
  attr_accessible :creators, :smart_collection_type

  attr_protected :identifier

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream
  has_metadata name: 'mods', type: NuModsDatastream
  has_file_datastream "thumbnail", type: FileContentDatastream

  has_many :child_files, property: :is_member_of, :class_name => "NuCoreFile"
  has_many :child_collections, property: :is_member_of, :class_name => "NuCollection"

  belongs_to :parent, property: :is_member_of, :class_name => "NuCollection"
  belongs_to :user_parent, property: :is_member_of, :class_name => "Employee"
  belongs_to :community_parent, property: :is_member_of, :class_name => "Community"

  def parent
    single_lookup(:is_member_of, [NuCollection, Community])
  end

  # Override parent= so that the string passed by the creation form can be used.
  def parent=(val)
    unique_assign_by_string(val, :is_member_of, [NuCollection, Community], allow_nil: true)

    if !val.nil?
      if val.instance_of? String
        self.properties.parent_id = val
      else
        self.properties.parent_id = val.pid
      end
    end
  end

  # Override user_parent= so that the string passed by the creation form can be used.
  def user_parent=(employee)
    if employee.instance_of?(String)
      self.add_relationship(:is_member_of, Employee.find_by_nuid(employee))
    elsif employee.instance_of? Employee
      self.add_relationship(:is_member_of, employee)
    else
      raise "user_parent= got passed a #{employee.class}, which doesn't work."
    end
  end

  # Depth first(ish) traversal of a graph.
  def each_depth_first
    self.child_collections.each do |child|
      child.each_depth_first do |c|
        yield c
      end
    end

    yield self
  end

  # Simple human readable label for objects.
  def type_label
    "Collection"
  end

  protected

    def belong_check
      if single_lookup(:is_member_of, [Community]) && single_lookup(:is_member_of, [NuCollection])
        errors.add(:identifier, "#{self.identifier} already has a parent relationship")
      end
    end
end
