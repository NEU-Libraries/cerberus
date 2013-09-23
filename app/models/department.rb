class Department < NuCollection

  before_create :tag_as_NuCollection

  has_many :employees, property: :is_member_of, class_name: "Employee"

  def tag_as_NuCollection
    self.RELS_EXT.add_relationship("hasModel", "info:fedora/afmodel:NuCollection") 
  end
end