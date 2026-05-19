# frozen_string_literal: true

class DerivativeCreationJob < ApplicationJob
  queue_as :default

  def perform(work_id, base, widths: nil)
    AtlasRb::Work.set_image_derivatives(
      work_id,
      **DerivativeCreator.call(base: base, widths: widths).symbolize_keys
    )
  end
end
