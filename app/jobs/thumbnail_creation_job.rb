# frozen_string_literal: true

class ThumbnailCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, base)
    AtlasRb::Work.set_thumbnails(work_id, **ThumbnailCreator.call(base: base), nuid: Current.nuid)
  end
end
