# frozen_string_literal: true

class Work < Resource
  include Modsable

  attribute :a_member_of, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)

  def self.create(collection_id:, title:)
    w = WorkCreator.call(parent_id: Collection.find(collection_id).id)
    w.plain_title = title
    Valkyrie.config.metadata_adapter.persister.save(resource: w)
  end
end
