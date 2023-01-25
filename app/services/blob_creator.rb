# frozen_string_literal: true

class BlobCreator < ApplicationService
  def initialize(work_id:, path:)
    @work_id = work_id
    @path = path
  end

  def call
    create_blob
  end

  private

    def create_blob
      # TODO: determine classification from mime type + extension
      fs = FileSetCreator.call(work_id: @work_id, classification: Classification.generic)
      b = Valkyrie.config.metadata_adapter.persister.save(resource: Blob.new).id
      b.file_identifiers += [create_file(@path, fs).id]
    end
end
