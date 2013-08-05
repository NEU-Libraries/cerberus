class NuCollection < ActiveFedora::Base
  include Hydra::ModelMixins::RightsMetadata  

  attr_accessor :nu_title, :nu_description

  has_metadata name: 'oaidc', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  # has_metadata name: 'MODS', type: NeuModsDatastream <--Need to implement this datastream type
  has_metadata name: 'crud', type: CrudDatastream

  delegate_to :oaidc, [:nu_title, :nu_description] 
end
