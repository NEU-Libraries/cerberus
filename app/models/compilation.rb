class Compilation < ActiveFedora::Base
  include Hydra::AccessControls::Permissions
  include Noidable

  # Fedora object which is a thin wrapper around assemblies
  # to tie in with solr/permissions/grouper

  property :assembly_id, predicate: ::RDF::Vocab::DC.identifier, multiple: false do |index|
    index.as :stored_searchable
  end

  def assembly
    return Assembly.find(self.assembly_id)
  end
end
