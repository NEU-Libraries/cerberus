class NuCollection < ActiveFedora::Base
  include Hydra::ModelMixins::RightsMetadata  

  has_metadata name: 'oaidc', type: NortheasternDublinCoreDatastream 
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  # has_metadata name: 'MODS', type: NuModsDatastream <--Need to implement this datastream type
end
