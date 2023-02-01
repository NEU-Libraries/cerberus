# frozen_string_literal: true

class CommunityCreator < ApplicationService
  def initialize(parent_id: nil, mods_xml: nil)
    @parent_id = parent_id
    @mods_xml = mods_xml.nil? ? mods_template : mods_xml
  end

  def call
    create_community
  end

  private

    def create_community
      meta = Valkyrie.config.metadata_adapter
      community = meta.persister.save(resource: Community.new(a_member_of: @parent_id))

      FileSetCreator.call(work_id: community.id, classification: Classification.descriptive_metadata)

      community.mods_xml = @mods_xml
      meta.persister.save(resource: community)
    end
end
