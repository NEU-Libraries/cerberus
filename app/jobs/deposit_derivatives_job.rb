# frozen_string_literal: true

# Generates the opt-in S/M/L download renditions a depositor chose on the
# metadata page, AFTER the deposit's IIIF assets already exist. They render from
# the Work's GATED JP2, anchored on the `service_file` Delegate: the thumbnail
# Delegate is NOT usable, since it points at the open capped JP2. The form can
# be submitted before that service exists, hence ServiceNotReady.
# See docs/downloads.md.
class DepositDerivativesJob < ApplicationJob
  queue_as :default

  class ServiceNotReady < StandardError; end

  # Also absorbs the optimistic-lock 500 if another job is still PATCHing the
  # same FileSet (the serial-PATCH concern documented in IiifAssetsJob).
  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "DepositDerivativesJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
    IncompleteFlag.set(job.arguments.first, nuid: job.current_nuid, reason: IncompleteReasons::DERIVATIVES)
  end
  # Declared after StandardError so it takes precedence (ActiveJob matches
  # rescue handlers in reverse declaration order).
  retry_on ServiceNotReady, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "DepositDerivativesJob: service never appeared for work #{job.arguments.first} — derivatives skipped"
    )
    IncompleteFlag.set(job.arguments.first, nuid: job.current_nuid, reason: IncompleteReasons::DERIVATIVES)
  end

  def perform(work_id, widths)
    return if widths.blank?

    base = gated_service_base(work_id)
    raise ServiceNotReady, "work #{work_id} has no IIIF service yet" if base.blank?

    DerivativeCreationJob.perform_now(work_id, base, widths: widths)
    IncompleteFlag.clear(work_id)
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
