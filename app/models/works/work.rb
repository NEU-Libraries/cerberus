class Works::Work < Hydra::Works::Work
  include Parentable
  include Noidable
  include Cerberus::Mods
  include Hydra::PCDM::ObjectBehavior
  include Hydra::AccessControls::Permissions
  include ModsDisplay::ModelExtension
  include Solr::GenericType

  mods_xml_source do |model|
    model.descMetadata.content
  end
end
