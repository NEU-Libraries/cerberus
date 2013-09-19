class Department < NuCollection

  before_create :tag_as_NuCollection

  has_many :employees, property: :has_affiliation, class_name: "Employee"

  def tag_as_NuCollection
    self.RELS_EXT.add_relationship("hasModel", "info:fedora/afmodel:NuCollection") 
  end
end