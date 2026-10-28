# frozen_string_literal: true

class ThumbnailCreationJob < ApplicationJob
  queue_as :default

  # `image` is an IiifImageCreator::Result, which ActiveJob cannot serialize, so
  # this job runs only through perform_now.
  def perform(work_id, image)
    AtlasRb::Resource.set_thumbnails(work_id, **ThumbnailCreator.call(image: image))
  end
end
