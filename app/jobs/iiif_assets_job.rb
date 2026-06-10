# frozen_string_literal: true

# Seeds a Work's IIIF assets from one staged image: JP2 into Cantaloupe's
# volume, then Delegate URLs PATCHed to Atlas.
#
# Two distinct asset families, with different generation policy:
#
# - Thumbnails (thumbnail / thumbnail_2x / preview): UNIVERSAL. Catalog
#   rows and show pages need them for every image-bearing Work, so they
#   are generated whenever this job runs.
# - Small/medium/large: DOWNLOAD RENDITIONS, generated only when the
#   caller passes `derivative_widths:`. IPTC ingest passes per-image
#   widths (its `widths_for` — v1-parity sizing). The single-file deposit
#   flow chooses sizes on the metadata page AFTER this job has run, via
#   DepositDerivativesJob (which recovers the JP2 base from the thumbnail
#   this job minted). Callers that pass nothing (deposit, XML loader,
#   multipage page 1) get thumbnails only here.
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
    return if derivative_widths.nil?

    DerivativeCreationJob.perform_now(work_id, base, widths: derivative_widths)
  end
end
