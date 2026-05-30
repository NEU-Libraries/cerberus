# frozen_string_literal: true

class IiifAssetsJob < ApplicationJob
  queue_as :default

  def perform(work_id, source_path, derivative_widths: nil)
    return if AtlasRb::Work.find(work_id).thumbnail.present?
    return unless File.exist?(source_path)

    base = MasterJp2.call(path: source_path)
    # Serial, not parallel: both sub-jobs PATCH Delegates that attach to the
    # same FileSet, and parallel execution races Atlas's optimistic-lock check
    # on the FileSet (StaleObjectError → 500 → Delegates not persisted).
    ThumbnailCreationJob.perform_now(work_id, base)
    DerivativeCreationJob.perform_now(work_id, base, widths: derivative_widths)
  end
end
