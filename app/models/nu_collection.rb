class NuCollection < ActiveFedora::Base
  include Hydra::ModelMethods
  include Hydra::ModelMixins::CommonMetadata  
  include Hydra::ModelMixins::RightsMetadata  

  attr_accessor :nu_title, :nu_description

  has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'mods', type: NuModsCollectionDatastream
  has_metadata name: 'crud', type: CrudDatastream

  delegate_to :DC, [:nu_title, :nu_description, :nu_identifier]
  delegate_to :mods, [:mods_title, :mods_abstract, :mods_identifier] 

  has_many :generic_files, property: :is_part_of 
  has_many :nu_collections, property: :is_part_of 
  # belongs_to :nu_collections, property: #What is?

  #Return all collections that this user can read
  def self.find_all_viewable(user) 
    collections = NuCollection.find(:all)
    collections.keep_if { |ele| ele.rightsMetadata.can_read?(user) }  
  end

  def nu_title_display 
    self.nu_title.first
  end

  def nu_description_display 
    self.nu_description.first 
  end

  def mods_title_display 
    self.mods_title.first 
  end

  def mods_abstract_display 
    self.mods_abstract.first 
  end
end
