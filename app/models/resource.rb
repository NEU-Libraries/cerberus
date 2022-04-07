# frozen_string_literal: true

class Resource < Valkyrie::Resource
  attribute :alternate_ids,
            Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true).default {
              [Valkyrie::ID.new(Minter.mint)]
            }

  enable_optimistic_locking

  def self.find(id)
    # expect noid
    Valkyrie.config.metadata_adapter.query_service.find_by_alternate_identifier(alternate_identifier: id)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    # try standard valkyrie
    Valkyrie.config.metadata_adapter.query_service.find_by(id: id)
  end

  def children
    result = []
    result.concat Valkyrie.config.metadata_adapter.query_service.find_inverse_references_by(
      resource: self, property: :a_member_of
    ).to_a
    result.concat Valkyrie.config.metadata_adapter.query_service.find_members(resource: self).to_a
    result.uniq
  end

  def noid
    alternate_ids.first.to_s
  end

  def to_param
    noid
  end

  def reload
    Resource.find(id)
  end

  def mods
    # Metadata::MODS.find_or_create_by(valkyrie_id: noid)
  end
end
