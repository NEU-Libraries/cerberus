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

  def add(object_id)
    # if collection
    # if work
  end

  def remove(object_id)
    # if collection
    # if work
  end

  def contains?(id)
    # find parent if work
    # compare with assembly collections
    # if work compare with assembly works
  end

  def intersects?(id_list)
    # find collections in list
    # find collections in assembly
    # make sets and compare
  end
end
