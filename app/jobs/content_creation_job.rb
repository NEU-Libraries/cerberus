# frozen_string_literal: true

class ContentCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, source_path, original_filename, idempotency_key)
    return unless File.exist?(source_path)

    AtlasRb::Blob.create(work_id, source_path, original_filename, idempotency_key: idempotency_key)
    AtlasRb::Work.complete(work_id)
  end
end
