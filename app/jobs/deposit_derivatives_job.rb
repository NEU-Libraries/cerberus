# frozen_string_literal: true

# Generates the opt-in download renditions a depositor chose on the metadata
# page — AFTER the deposit's IIIF assets already exist.
#
# The chosen S/M/L sizes render from the Work's GATED full-resolution JP2,
# whose base is recoverable from the `service_file` Delegate that
# IiifAssetsJob set at ingest. The thumbnail Delegate is NOT usable here: it
# points at the OPEN capped JP2, which is too small to produce download
# renditions — hence the service_file, not the thumbnail, is the anchor.
#
# Race: the user can submit the metadata form before IiifAssetsJob has
# PATCHed the service. ServiceNotReady rides retry_on (≈16 minutes of
# polynomially-longer cover); if it never appears (MasterJp2 failure, dead
# queue), attempts exhaust and the block logs and swallows — the deposit and
# its metadata are untouched, and the user can revisit the metadata page to
# request sizes again. There is no ingest row to mark failed here, so the
# log line is the whole exhaustion story.
class DepositDerivativesJob < ApplicationJob
  queue_as :default

  class ServiceNotReady < StandardError; end

  # Also absorbs transient Atlas failures, including the optimistic-lock
  # 500 if another job is still PATCHing the same FileSet (the serial-PATCH
  # concern documented in IiifAssetsJob).
  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "DepositDerivativesJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
  end
  # Declared after StandardError so it takes precedence (ActiveJob matches
  # rescue handlers in reverse declaration order).
  retry_on ServiceNotReady, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "DepositDerivativesJob: service never appeared for work #{job.arguments.first} — derivatives skipped"
    )
  end

  def perform(work_id, widths)
    return if widths.blank?

    base = gated_service_base(work_id)
    raise ServiceNotReady, "work #{work_id} has no IIIF service yet" if base.blank?

    DerivativeCreationJob.perform_now(work_id, base, widths: widths)
  end

  private

    # The service_file Delegate's URI is the gated IIIF base itself (no
    # size/region suffix), so it is handed straight to DerivativeCreator.
    # Match on the stable `role` token — `use` is Atlas's human display label.
    def gated_service_base(work_id)
      AtlasRb::Work.file_sets(work_id)
                   .flat_map { |file_set| Array(file_set['assets']) }
                   .find { |asset| asset['role'].to_s == 'service_file' && asset['uri'].present? }
                   &.dig('uri')
    end
end
