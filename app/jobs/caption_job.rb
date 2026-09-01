# frozen_string_literal: true

# Attaches a depositor's WebVTT file to a Work as its caption track, replacing
# rather than accumulating.
#
# The wait for the Work's primary file is load-bearing, not defensive: a caption
# also carries the role `original_file`, so attaching one first lets a deposit
# complete around captions alone and Atlas writes a METS structMap omitting the
# video. See docs/derivatives.md.
class CaptionJob < ApplicationJob
  include PrimaryFilePresence

  queue_as :default

  class PrimaryFileMissing < StandardError; end

  # Exhausting the budget leaves the Work with no captions and says so in the
  # log. That is the right outcome: a Work whose video never landed has nothing
  # to caption, and the deposit itself is already on the needs-attention list.
  retry_on PrimaryFileMissing, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "CaptionJob: work #{job.arguments.first} never received its primary file — captions not attached"
    )
  end

  # A Blob write bumps the Work's optimistic lock, so this can lose a race with
  # the deposit's own finalization even after the wait above.
  retry_on AtlasRb::StaleResourceError, attempts: 5, wait: :polynomially_longer

  def perform(work_id, staged_path, original_filename, idempotency_key)
    return unless File.exist?(staged_path)
    raise PrimaryFileMissing, "work #{work_id} has no primary file yet" unless primary_file?(work_id)

    existing = CaptionTrack.for(AtlasRb::Work.assets(work_id))

    if existing
      AtlasRb::Blob.update(existing.noid, staged_path, idempotency_key: idempotency_key)
    else
      AtlasRb::Blob.create(work_id, staged_path, original_filename, idempotency_key: idempotency_key)
    end
  end
end
