# frozen_string_literal: true

class BlobCreator < ApplicationService
  include FileHelper
  include MimeHelper

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
      fs = FileSetCreator.call(work_id: @work_id, classification: assign_classification(@path))
      b = Valkyrie.config.metadata_adapter.persister.save(resource: Blob.new)
      b.file_identifiers += [create_file(@path, fs).id]
    end
end
