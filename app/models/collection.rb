class Collection < ActiveFedora::Base
  include Hydra::Works::CollectionBehavior
  include Hydra::AccessControls::Permissions

  belongs_to :community, class_name: 'Community', predicate: ActiveFedora::RDF::Fcrepo::RelsExt.isPartOf

  def parent=(parent_obj)
    if parent_obj.class == Collection
      parent_obj.members << self
      parent_obj.save!
    elsif parent_obj.class == Community
      self.community = parent_obj
      self.save!
    end
  end

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :description, predicate: ::RDF::Vocab::DC.description, multiple: false do |index|
    index.as :stored_searchable
  end
end
