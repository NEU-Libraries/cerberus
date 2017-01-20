class Community < ActiveFedora::Base
  include Hydra::AccessControls::Permissions
  include Hydra::PCDM::ObjectBehavior
  include Parentable
  include Noidable

  belongs_to :community, :class_name => "Community", predicate: ActiveFedora::RDF::Fcrepo::RelsExt.isPartOf

  has_many :collections
  has_many :communities

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :description, predicate: ::RDF::Vocab::DC.description, multiple: false do |index|
    index.as :stored_searchable
  end
end
