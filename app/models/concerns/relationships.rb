module Relationships
  extend ActiveSupport::Concern

  included do
    def self.find(id)
      # expect noid
      Valkyrie.config.metadata_adapter.query_service.find_by_alternate_identifier(alternate_identifier: id)
    rescue Valkyrie::Persistence::ObjectNotFoundError
      # try standard valkyrie
      Valkyrie.config.metadata_adapter.query_service.find_by(id: id)
    end
  end

  def parent
    Valkyrie.config.metadata_adapter.query_service.find_references_by(resource: self, property: :a_member_of).first
  end

  def children
    result = []
    result.concat Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(
      resource: self, property: :a_member_of
    ).to_a
    result.concat Valkyrie.config.metadata_adapter.query_service.find_members(resource: self).to_a
    result.uniq
  end

end
