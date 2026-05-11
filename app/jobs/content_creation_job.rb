# frozen_string_literal: true

class ContentCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, source_path, original_filename)
    return if AtlasRb::Work.files(work_id).any? { |f| f.original_filename == original_filename }
    return unless File.exist?(source_path)

    AtlasRb::Blob.create(work_id, source_path, original_filename)
  end
end
