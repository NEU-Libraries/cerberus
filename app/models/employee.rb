class Employee < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity

  attr_accessor :email, :nuid
  attr_protected :identifier

  belongs_to :parent, :property => :is_member_of, :class_name => 'Department'

end