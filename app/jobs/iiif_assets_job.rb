# frozen_string_literal: true

# Seeds a Work's IIIF assets from one staged source: an image, or a PDF whose
# first page MasterJp2 rasterizes.
#
# Thumbnails come from the OPEN display-capped JP2 and are universal;
# service_file and any S/M/L renditions come from the GATED full-resolution one.
# Which families a call produces depends on `derivative_widths:` —
# see docs/derivatives.md.
class IiifAssetsJob < ApplicationJob
  queue_as :default

  # Broken or encrypted sources (poppler can't open every PDF we're handed)
  # surface as Vips::Error from MasterJp2. Retrying can't fix the bytes, and
  # enrichment must never fail a deposit — skip the assets and move on
  # (v1 parity: rescue, notify, continue).
  discard_on Vips::Error do |job, exception|
    Rails.logger.warn(
      "IiifAssetsJob: unreadable source for work #{job.arguments.first} — thumbnails skipped (#{exception.message})"
    )
    IncompleteFlag.set(job.arguments.first, nuid: job.current_nuid, reason: IncompleteReasons::THUMBNAILS)
  end

  def perform(work_id, source_path, derivative_widths: nil, refresh: false)
    return if !refresh && AtlasRb::Work.find(work_id).thumbnail.present?
    return unless File.exist?(source_path)

    result = MasterJp2.call(path: source_path)
    # Serial, not parallel: these all PATCH Delegates that attach to the same
    # FileSet, and parallel execution races Atlas's optimistic-lock check on
    # the FileSet (StaleObjectError → 500 → Delegates not persisted).
    ThumbnailCreationJob.perform_now(work_id, result.open_base)
    persist_service!(work_id, result.gated_base)

    IncompleteFlag.clear(work_id)

    widths = derivative_widths || (refresh ? existing_widths(work_id) : nil)
    return if widths.nil?

    DerivativeCreationJob.perform_now(work_id, result.gated_base, widths: widths)
  end

  private

    def existing_widths(work_id)
      DerivativeCreator.existing_widths(AtlasRb::Work.assets(work_id))
    end

    def persist_service!(work_id, gated_base)
      file_set_pid = AtlasRb::Work.file_sets(work_id).first&.[]('noid')
      AtlasRb::FileSet.set_iiif_service(file_set_pid, gated_base) if file_set_pid
    end
end
