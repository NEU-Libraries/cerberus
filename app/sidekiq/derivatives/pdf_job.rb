# frozen_string_literal: true

module Derivatives
  class PdfJob
    include Sidekiq::Job
    include FileHelper

    def perform(file_id, work_id)
      file = Valkyrie.config.storage_adapter.find_by(id: file_id)
      # Make PDF from Word binary
      if file.present? && Work.find(work_id).present?
        new_file = Tempfile.new
        IO.copy_stream(file, new_file)

        # TODO: move off of hard coded temp path, use temporary file helper that is env independent
        derivative_path = Rails.root.join("tmp/#{SecureRandom.uuid}.pdf").to_s
        Libreconv.convert(new_file.path, derivative_path)

        fs = FileSetCreator.call(work_id: work_id, classification: Classification.derivative)
        b = Valkyrie.config.metadata_adapter.persister.save(resource: Blob.new)
        b.file_identifiers += [create_file(derivative_path, fs).id]
      end
    end
  end
end
