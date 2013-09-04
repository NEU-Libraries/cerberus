class Compilation < ActiveFedora::Base
  include Hydra::ModelMethods
  include Hydra::ModelMixins::CommonMetadata  
  include Hydra::ModelMixins::RightsMetadata
  include ActiveModel::MassAssignmentSecurity

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream 
  has_metadata name: 'properties', type: DrsPropertiesDatastream 

  attr_accessible :title, :identifier, :depositor, :description

  has_many :entries, class_name: "NuCoreFile",  property: :has_member

  def self.users_compilations(user) 
    Compilation.find(:all).keep_if { |file| file.depositor == user.nuid } 
  end 

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
    self.rightsMetadata.permissions({person: value}, 'edit')  
  end

  def depositor 
    self.properties.depositor.first
  end

  # Returns the pids of all objects tagged as entries 
  # in this collection.
  def entry_pids
    a = self.relationships(:has_member) 
    return a.map{ |rels| trim_to_pid(rels) } 
  end

  # Returns all NuCoreFile objects tagged as entries 
  # in this collection. 
  def entries
    a = self.relationships(:has_member) 
    return a.map { |rels| NuCoreFile.find(trim_to_pid(rels)) } 
  end

  def add_entry(value) 
    if value.instance_of?(NuCoreFile)
      add_relationship(:has_member, value) 
    elsif value.instance_of?(String) 
      object = NuCoreFile.find(value) 
      add_relationship(:has_member, object) 
    else
      raise "Add item can only take a string or an instance of a Core object" 
    end
  end

  def remove_entry(value) 
    if value.instance_of?(NuCoreFile) 
      remove_relationship(:has_member, value) 
    elsif value.instance_of?(String) 
      object = NuCoreFile.find(value)
      remove_relationship(:has_member, object)  
    end
  end

  private 

    # Takes a string of form "info:fedora/neu:abc123" 
    # and returns just the pid
    def trim_to_pid(string)
      return string.split('/').last 
    end 
end