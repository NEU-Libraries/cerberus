class Department < NuCollection

  before_create :tag_as_NuCollection

  has_many :employees, property: :has_affiliation, class_name: "Employee"
  has_many :child_departments, property: :is_member_of, :class_name => "Department"

  belongs_to :parent, property: :is_member_of, :class_name => "Department"

  def tag_as_NuCollection
    self.add_relationship(:has_model, "info:fedora/afmodel:NuCollection") 
  end
end