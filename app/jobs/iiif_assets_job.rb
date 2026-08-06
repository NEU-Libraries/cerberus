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
#   when the caller passes `derivative_widths:`. IPTC ingest passes per-image
#   widths (its `widths_for` — v1-parity sizing). The single-file deposit flow
#   chooses sizes on the metadata page AFTER this job has run, via
#   DepositDerivativesJob (which recovers the gated base from the service_file
#   Delegate this job set). Callers that pass nothing at seed time (deposit,
#   XML loader, multipage page 1) get thumbnails + service only here.
#   On a `refresh:` the widths come from the Work itself instead — see
#   #existing_widths.
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

  # `refresh:` distinguishes "seed the assets" from "re-derive them". The
  # existing-thumbnail guard makes a *deposit* idempotent under Solid Queue
  # retries, but it reads as "already done" on a Work whose bytes have since
  # been replaced — where a thumbnail is always present and is precisely what
  # must change. Left unguarded there, the job returned immediately and the
  # page kept showing the superseded image while the download served the new
  # one, which is indistinguishable from the replace having failed.
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

    # A replace passes no widths: the sizes were chosen once, at deposit, and
    # only the Work's stored rendition URIs still record them. Reading them back
    # keeps the download renditions in step with everything else the refresh
    # rebuilds. Left out, the thumbnail, the deep zoom and the displayed image
    # all move to the new bytes while every sized download goes on serving the
    # superseded picture.
    def existing_widths(work_id)
      DerivativeCreator.existing_widths(AtlasRb::Work.assets(work_id))
    end

    # The gated full-res base rides a service_file Delegate on the (single)
    # content FileSet, so DepositDerivativesJob can recover it for deferred
    # download renditions. Skipped if the FileSet isn't listed yet.
    def persist_service!(work_id, gated_base)
      file_set_pid = AtlasRb::Work.file_sets(work_id).first&.[]('noid')
      AtlasRb::FileSet.set_iiif_service(file_set_pid, gated_base) if file_set_pid
    end
end
