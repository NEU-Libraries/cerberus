# frozen_string_literal: true

class CommunityCreator < ApplicationService
  def initialize(parent_id: nil)
    @parent_id = parent_id
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
      return community
    end
end
