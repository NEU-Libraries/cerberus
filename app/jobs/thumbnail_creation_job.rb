# frozen_string_literal: true

class ThumbnailCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, source_path)
    return if AtlasRb::Work.find(work_id).thumbnail.present?
    return unless File.exist?(source_path)

    uuid = ThumbnailCreator.call(path: source_path)
    AtlasRb::Work.metadata(work_id, 'thumbnail' => uuid)
  end
end
