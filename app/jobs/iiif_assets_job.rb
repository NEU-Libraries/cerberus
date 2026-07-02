# frozen_string_literal: true

# Seeds a Work's IIIF assets from one staged source — an image, or a PDF
# whose first page MasterJp2 rasterizes (deposited directly or converted
# from Word/PowerPoint by PdfRenditionJob). MasterJp2 mints two JP2s (a
# capped display copy + a full-resolution copy); this job PATCHes their
# Delegate URLs to Atlas.
#
# Asset families, each on its own pipe:
#
# - Thumbnails (thumbnail / thumbnail_2x / preview): UNIVERSAL, served from
#   the OPEN (display-capped) JP2. Catalog rows and show pages need them for
#   every image-bearing Work, so they are generated whenever this job runs.
# - service_file: the GATED full-resolution IIIF base, PATCHed onto the
#   content FileSet. It is the deep-zoom source AND the anchor from which
#   DepositDerivativesJob later recovers the base for opt-in S/M/L.
# - Small/medium/large: DOWNLOAD RENDITIONS off the GATED base, generated
#   only when the caller passes `derivative_widths:`. IPTC ingest passes
#   per-image widths (its `widths_for` — v1-parity sizing). The single-file
#   deposit flow chooses sizes on the metadata page AFTER this job has run,
#   via DepositDerivativesJob (which recovers the gated base from the
#   service_file Delegate this job set). Callers that pass nothing (deposit,
#   XML loader, multipage page 1) get thumbnails + service only here.
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
  end

  def perform(work_id, source_path, derivative_widths: nil)
    return if AtlasRb::Work.find(work_id).thumbnail.present?
    return unless File.exist?(source_path)

    result = MasterJp2.call(path: source_path)
    # Serial, not parallel: these all PATCH Delegates that attach to the same
    # FileSet, and parallel execution races Atlas's optimistic-lock check on
    # the FileSet (StaleObjectError → 500 → Delegates not persisted).
    ThumbnailCreationJob.perform_now(work_id, result.open_base)
    persist_service!(work_id, result.gated_base)
    return if derivative_widths.nil?

    DerivativeCreationJob.perform_now(work_id, result.gated_base, widths: derivative_widths)
  end

  private

    # The gated full-res base rides a service_file Delegate on the (single)
    # content FileSet, so DepositDerivativesJob can recover it for deferred
    # download renditions. Skipped if the FileSet isn't listed yet.
    def persist_service!(work_id, gated_base)
      file_set_pid = AtlasRb::Work.file_sets(work_id).first&.[]('noid')
      AtlasRb::FileSet.set_iiif_service(file_set_pid, gated_base) if file_set_pid
    end
end
