class Department < NuCollection

  before_create :tag_as_NuCollection

  has_many :nu_employees, property: :is_member_of, class_name: "NuEmployee"

  def tag_as_NuCollection
    self.RELS_EXT.add_relationship("hasModel", "info:fedora/afmodel:NuCollection") 
  end
end