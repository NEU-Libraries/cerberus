# frozen_string_literal: true

class CollectionCreator < ApplicationService
  def initialize(parent_id:, mods_xml: nil)
    @parent_id = parent_id
    @mods_xml = mods_xml.nil? ? mods_template : mods_xml
  end

  def call
    create_collection
  end

  private

    def create_collection
      meta = Valkyrie.config.metadata_adapter
      collection = meta.persister.save(resource: Collection.new(a_member_of: @parent_id))

      FileSetCreator.call(work_id: collection.id, classification: Classification.descriptive_metadata)

      collection.mods_xml = @mods_xml
      meta.persister.save(resource: collection)
    end
end
