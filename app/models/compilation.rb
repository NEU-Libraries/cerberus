class Compilation < ActiveFedora::Base
  include Hydra::ModelMethods
  include Hydra::ModelMixins::CommonMetadata  
  include Hydra::ModelMixins::RightsMetadata
  include ActiveModel::MassAssignmentSecurity

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream 
  has_metadata name: 'properties', type: DrsPropertiesDatastream 

  attr_accessible :title, :identifier, :depositor, :description

  has_many :entries, class_name: "GenericFile",  property: :has_member 

  def title=(value)
    self.DC.nu_title = value 
  end

  def title 
    self.DC.nu_title.first 
  end

  def description=(value)
    self.DC.nu_description = value 
  end

  def description 
    self.DC.nu_description.first 
  end

  def identifier=(value) 
    self.DC.nu_identifier = value 
  end

  def identifier
    self.DC.nu_identifier.first 
  end

  def depositor=(value) 
    self.properties.depositor = value 
  end

  def depositor 
    self.properties.depositor.first
  end

  def add_entry(value) 
    if value.instance_of?(GenericFile)
      add_relationship(:has_member, value) 
    elsif value.instance_of?(String) 
      object = GenericFile.find(value) 
      add_relationship(:has_member, object) 
    else
      raise "Add item can only take a string or an instance of a Core object" 
    end
  end

  def remove_entry(value) 
    if value.instance_of?(GenericFile) 
      remove_relationship(:has_member, value) 
    elsif value.instance_of?(String) 
      object = GenericFile.find(value)
      remove_relationship(:has_member, object)  
    end
  end
end