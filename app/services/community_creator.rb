# frozen_string_literal: true

class CommunityCreator < ApplicationService
  def initialize(parent_id: nil, mods_xml: nil)
    @parent_id = parent_id
    @mods_xml = !mods_xml.nil? ? mods_xml : mods_template
  end

  def call
    create_community
  end

  private

    def create_community
      meta = Valkyrie.config.metadata_adapter
      community = meta.persister.save(resource: Community.new(a_member_of: @parent_id))

      # make blob shell
      fs = meta.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
      fs.member_ids += [
        meta.persister.save(resource: Blob.new(descriptive_metadata_for: community.id)).id
      ]
      fs.a_member_of = community.id
      meta.persister.save(resource: fs)

      community.mods_xml = @mods_xml
      meta.persister.save(resource: community)
    end
end
