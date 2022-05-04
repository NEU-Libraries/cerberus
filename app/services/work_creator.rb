# frozen_string_literal: true

class WorkCreator < ApplicationService
  def initialize(parent_id: nil)
    @parent_id = parent_id
  end

  def call
    create_work
  end

  private

    def create_work
      meta = Valkyrie.config.metadata_adapter
      work = meta.persister.save(resource: Work.new(a_member_of: @parent_id))

      # make blob shell
      fs = meta.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
      fs.member_ids += [
        meta.persister.save(resource: Blob.new(descriptive_metadata_for: work.id)).id
      ]
      fs.a_member_of = work.id
      meta.persister.save(resource: fs)
      return work
    end
end
