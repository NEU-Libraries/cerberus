# frozen_string_literal: true

class ThumbnailCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, source_path)
    return if AtlasRb::Work.find(work_id).thumbnail.present?
    return unless File.exist?(source_path)

    base = MasterJp2.call(path: source_path)
    AtlasRb::Work.set_thumbnails(work_id, **ThumbnailCreator.call(base: base).symbolize_keys)
  end
end
