class Department < NuCollection

  before_create :tag_as_NuCollection

  # Uncomment this line to get the correct relationship, doesn't work
  # due to the lack of a person class atm obviously. 
  # has_many :staff, property: :is_member_of, class_name: "Person"

  def tag_as_NuCollection
    self.RELS_EXT.add_relationship("hasModel", "info:fedora/afmodel:NuCollection") 
  end
end