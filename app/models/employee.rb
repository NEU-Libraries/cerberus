class Employee < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity

  attr_accessible :nuid, :name
  attr_protected :identifier

  has_metadata name: 'details', type: DrsEmployeeDatastream

  belongs_to :parent, :property => :is_member_of, :class_name => 'Department'

  def name=(string)
    self.details.name = string
  end

  def name
    self.details.name
  end

  def nuid=(string)
    self.details.nuid = string
  end

  def nuid
    self.details.nuid
  end
end