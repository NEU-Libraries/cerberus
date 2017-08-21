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

  validates :title, presence: { message: 'Your work must have a title.' }
  validates :keywords, presence: { message: 'Your work must have at least one keyword.' }

  property :in_progress, predicate: ::RDF::URI.new('https://repository.library.northeastern.edu/ns#inProgress'), multiple: false do |index|
    index.as :stored_searchable
  end
end
