# frozen_string_literal: true

class IiifAssetsJob < ApplicationJob
  queue_as :default

  def perform(work_id, source_path, derivative_widths: nil)
    return if AtlasRb::Work.find(work_id).thumbnail.present?
    return unless File.exist?(source_path)

    base = MasterJp2.call(path: source_path)
    ThumbnailCreationJob.perform_later(work_id, base)
    DerivativeCreationJob.perform_later(work_id, base, widths: derivative_widths)
  end
end
