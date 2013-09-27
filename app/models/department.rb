class Department < NuCollection

  before_create :tag_as_NuCollection

  has_many :employees, property: :has_affiliation, class_name: "Employee"
  has_many :child_departments, property: :is_member_of, :class_name => "Department"

  belongs_to :parent, property: :is_member_of, :class_name => "Department"

  def tag_as_NuCollection
    self.add_relationship(:has_model, "info:fedora/afmodel:NuCollection") 
  end

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
end