# frozen_string_literal: true

class DerivativeCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, base)
    AtlasRb::Work.set_image_derivatives(work_id, **DerivativeCreator.call(base: base).symbolize_keys)
  end
end
