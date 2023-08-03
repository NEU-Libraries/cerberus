class Community < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  include Hydra::ModelMixins::RightsMetadata
  include Hydra::ModelMethods
  include Cerberus::Rights::MassPermissions
  include Cerberus::Rights::Embargoable
  include Cerberus::Rights::InheritedRestrictions
  include Cerberus::MetadataAssignment
  include Cerberus::Relationships
  include Cerberus::Find
  include Cerberus::Persist

  has_metadata name: 'DC', type: DublinCoreDatastream
  has_metadata name: 'mods', type: ModsDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: PropertiesDatastream

  has_file_datastream "thumbnail_1", type: FileContentDatastream
  has_file_datastream "thumbnail_2", type: FileContentDatastream
  has_file_datastream "thumbnail_3", type: FileContentDatastream

  attr_accessible :title, :description, :parent
  attr_protected :identifier

  has_many :employees, property: :has_affiliation, class_name: "Employee"
  has_many :child_collections, property: :is_member_of, :class_name => "Collection"
  has_many :child_communities, property: :has_affiliation, :class_name => "Community"

  belongs_to :parent, property: :has_affiliation, :class_name => "Community"

  def has_theses?
    query_result = ActiveFedora::SolrService.query("smart_collection_type_tesim:\"Theses and Dissertations\"  AND parent_id_tesim:\"#{self.pid}\"")
    return query_result.length > 0
  end

  def to_solr(solr_doc = Hash.new())
    super(solr_doc)
    solr_doc["type_sim"] = I18n.t("drs.display_labels.#{self.class}.name")
    return solr_doc
  end

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
