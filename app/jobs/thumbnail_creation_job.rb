# frozen_string_literal: true

class ThumbnailCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, base)
    AtlasRb::Resource.set_thumbnails(work_id, **ThumbnailCreator.call(base: base))
  end
end
