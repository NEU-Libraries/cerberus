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
      classification = assign_classification(@path)
      fs = FileSetCreator.call(work_id: @work_id, classification: classification)
      b = Blob.new
      file_id = create_file(@path, fs).id
      b.file_identifiers += [file_id]
      Valkyrie.config.metadata_adapter.persister.save(resource: b)

      # TODO: make a derivative handler that just takes a path and runs all the logic
      # if FileSet is text && is a word document, kick off PDF derivative job
      if (classification == Classification.text) && (ext_check(@path) == Classification.text)
        # Run job
        Derivatives::PdfJob.perform_async(file_id, @work_id)
      end
    end
end
