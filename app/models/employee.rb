class Employee < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  
  attr_accessible :email, :nuid
  attr_protected :identifier

  belongs_to :parent, :property => :is_member_of, :class_name => 'NuCollection'

end