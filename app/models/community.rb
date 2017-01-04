class Community < ActiveFedora::Base
  include Hydra::AccessControls::Permissions
  
  has_many :collections

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :description, predicate: ::RDF::Vocab::DC.description, multiple: false do |index|
    index.as :stored_searchable
  end
end
