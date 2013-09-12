class Department < NuCollection

  # Doing this as a before create hook (the sensible thing) inserts the relationship, 
  # but doesn't seem to allow lookup on it using self.relationships(:is_derivation_of)
  # until you reload the object.  
  before_create :tag_as_NuCollection

  # Uncomment this line to get the correct relationship, doesn't work
  # due to the lack of a person class atm obviously. 
  # has_many :staff, property: :is_member_of, class_name: "Person"

  def tag_as_NuCollection
    self.add_relationship(:is_derivation_of, "info:fedora/afmodel:NuCollection") 
  end
end