# frozen_string_literal: true

# Generates the opt-in download renditions a depositor chose on the
# metadata page — AFTER the deposit's thumbnails already exist.
#
# IiifAssetsJob can't be reused here: it guards on `thumbnail.present?`
# (seed-once semantics) and re-encodes the JP2. This job inverts that
# guard — it REQUIRES the thumbnail, because the JP2 base isn't persisted
# in Cerberus and is recoverable only from the thumbnail Delegate URI
# ("#{base}/full/!85,85/0/default.jpg", built by ThumbnailCreator — the
# split below is size-agnostic but coupled to that URL shape; change them
# together).
#
# Race: the user can submit the metadata form before ThumbnailCreationJob
# has PATCHed. ThumbnailNotReady rides retry_on (≈16 minutes of
# polynomially-longer cover); if thumbnails never appear (MasterJp2
# failure, dead queue), attempts exhaust and the block logs and swallows —
# the deposit and its metadata are untouched, and the user can revisit the
# metadata page to request sizes again. There is no ingest row to mark
# failed here, so the log line is the whole exhaustion story.
class DepositDerivativesJob < ApplicationJob
  queue_as :default

  class ThumbnailNotReady < StandardError; end

  # Also absorbs transient Atlas failures, including the optimistic-lock
  # 500 if ContentCreationJob is still PATCHing the same FileSet (the
  # serial-PATCH concern documented in IiifAssetsJob).
  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "DepositDerivativesJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
  end
  # Declared after StandardError so it takes precedence (ActiveJob matches
  # rescue handlers in reverse declaration order).
  retry_on ThumbnailNotReady, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "DepositDerivativesJob: thumbnail never appeared for work #{job.arguments.first} — derivatives skipped"
    )
  end

  def perform(work_id, widths)
    return if widths.blank?

    thumbnail = AtlasRb::Work.find(work_id)&.thumbnail
    raise ThumbnailNotReady, "work #{work_id} has no thumbnail yet" if thumbnail.blank?

    DerivativeCreationJob.perform_now(work_id, thumbnail.split('/full/').first, widths: widths)
  end
end
