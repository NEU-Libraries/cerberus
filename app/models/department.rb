class Department < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  include Hydra::ModelMixins::RightsMetadata
  include Drs::Rights::MassPermissions
  include Drs::Rights::Embargoable
  include Drs::Rights::InheritedRestrictions
  include Drs::MetadataAssignment

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: DrsPropertiesDatastream

  attr_accessible :title, :description, :parent
  attr_protected :identifier

  has_many :employees, property: :has_affiliation, class_name: "Employee"
  has_many :child_collections, property: :is_member_of, :class_name => "NuCollection"
  has_many :child_departments, property: :has_affiliation, :class_name => "Department"

  belongs_to :department, property: :has_affiliation, :class_name => "Department"

  # Override parent= so that the string passed by the creation form can be used. 
  def parent=(department_id)
    if department_id.nil? 
      return true #Controller level validations are used to ensure that end users cannot do this.  
    elsif department_id.instance_of?(String) 
      self.add_relationship(:is_member_of, Department.find(department_id))
    elsif department_id.instance_of?(Department)
      self.add_relationship(:is_member_of, department_id) 
    else
      raise "parent= got passed a #{department_id.class}, which doesn't work."
    end
  end

  def permissions=(hash)
    self.set_permissions_from_new_form(hash)
  end

  # Accepts a hash of the following form:
  # ex. {'permissions1' => {'identity_type' => val, 'identity' => val, 'permission_type' => val }, 'permissions2' => etc. etc. }
  # Tosses out param sets that are missing an identity.  Which is nice.   
  def set_permissions_from_new_form(params)
    params.each do |perm_hash| 
      identity_type = perm_hash[1]['identity_type']
      identity = perm_hash[1]['identity']
      permission_type = perm_hash[1]['permission_type'] 

      if identity != 'public' && identity != 'registered' 
        self.rightsMetadata.permissions({identity_type => identity}, permission_type)
      end 
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

  # Return every descendent collection of this collection
  def all_descendent_collections
    result = [] 
    each_depth_first do |child|
      result << child 
    end
    return result 
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