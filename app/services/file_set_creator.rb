# frozen_string_literal: true

class FileSetCreator < ApplicationService
  def initialize(work_id:, classification:)
    @work_id = work_id
    @classification = classification
  end

  def call
    create_file_set
  end

  private

    def create_file_set
      meta = Valkyrie.config.metadata_adapter

      # make blob shell
      fs = FileSet.new(type: @classification.name)
      fs.member_ids += [
        if @classification.symbol == :descriptive_metadata
          meta.persister.save(resource: Blob.new(descriptive_metadata_for: @work_id)).id
        end
      ]
      fs.a_member_of = @work_id
      meta.persister.save(resource: fs)
    end
end
