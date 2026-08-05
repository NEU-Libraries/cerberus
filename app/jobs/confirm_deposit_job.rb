# frozen_string_literal: true

# Completes an interactive deposit once the depositor has confirmed its metadata
# AND the primary Blob has landed. Enqueued by the deposit form's second-page
# save; the Work stays in_progress until both are true.
#
# Both halves are load-bearing. Atlas builds the Work-level METS structMap when a
# Work completes, so completing before the primary Blob exists would record a
# preservation structure that omits the file — which is why Atlas's own contract
# asks callers to complete only after confirming the expected children are
# deposited. And a human may save the metadata page seconds after upload, well
# before ContentCreationJob has written anything, so the check cannot be skipped
# on the assumption that the queue wins the race.
#
# The wait keys on the artifact via PrimaryFilePresence — same idiom as
# DepositDerivativesJob's ServiceNotReady.
#
# Exhausting the retries leaves the Work in_progress. That is the correct
# outcome, not a failure to paper over: the deposit genuinely has no primary
# file, so it stays out of public discovery and appears on the needs-attention
# list for someone to finish or withdraw.
class ConfirmDepositJob < ApplicationJob
  include PrimaryFilePresence

  queue_as :default

  class PrimaryFileMissing < StandardError; end

  retry_on PrimaryFileMissing, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "ConfirmDepositJob: work #{job.arguments.first} never received its primary file — left in progress"
    )
  end

  def perform(work_id)
    raise PrimaryFileMissing, "work #{work_id} has no primary file yet" unless primary_file?(work_id)

    AtlasRb::Work.complete(work_id)
  end
end
