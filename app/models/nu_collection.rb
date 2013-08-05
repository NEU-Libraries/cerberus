class NuCollection < ActiveFedora::Base
  include Hydra::ModelMixins::RightsMetadata  

  attr_accessor :nu_title, :nu_description

  has_metadata name: 'oaidc', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'mods', type: NuModsCollectionDatastream
  has_metadata name: 'crud', type: CrudDatastream

  delegate_to :oaidc, [:nu_title, :nu_description, :nu_identifier]
  delegate_to :mods, [:mods_title, :mods_abstract, :mods_identifier] 

  has_many :generic_files, property: :is_part_of 
  has_many :nu_collections, property: :is_part_of 
  # belongs_to :nu_collections, property: #What is?
  
end
