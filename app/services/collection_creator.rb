# frozen_string_literal: true

class CollectionCreator < ApplicationService
  def initialize(parent_id:)
    @parent_id = parent_id
  end

  def call
    create_collection
  end

  private

    def create_collection
      meta = Valkyrie.config.metadata_adapter
      collection = meta.persister.save(resource: Collection.new(a_member_of: @parent_id))

      # make blob shell
      fs = meta.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
      fs.member_ids += [
        meta.persister.save(resource: Blob.new(descriptive_metadata_for: collection.id)).id
      ]
      fs.a_member_of = collection.id
      meta.persister.save(resource: fs)
      return collection
    end
end
