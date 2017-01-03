class Collection < ActiveFedora::Base
  include Hydra::Works::CollectionBehavior
  belongs_to :community, class_name: 'Community', predicate: ActiveFedora::RDF::Fcrepo::RelsExt.isPartOf
end
