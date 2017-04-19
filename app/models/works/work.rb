class Works::Work < Hydra::Works::Work
  include Parentable
  include Noidable
  include Hydra::PCDM::ObjectBehavior
  include Hydra::AccessControls::Permissions
  include ModsDisplay::ModelExtension
  include Cerberus::Mods
  include Cerberus::Permissions

  mods_xml_source do |model|
    model.descMetadata.content
  end

  self.indexer = WorkIndexer
end
