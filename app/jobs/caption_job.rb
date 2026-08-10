# frozen_string_literal: true

# Attaches a depositor's WebVTT file to a Work as its caption track.
#
# Backgrounded like the other Blob writers so the request returns before the
# bytes cross the wire, and staged to disk first (UploadStaging) for the same
# reason.
#
# Replaces rather than accumulates. A Work has one caption track, so a second
# upload rewrites the bytes of the Blob already there — Blob.update appends an
# OCFL revision and preserves the NOID, so the superseded captions stay
# retrievable and every page already pointing at that Blob keeps working. Only
# the first upload creates.
#
# It waits for the Work's primary file, and that guard is load-bearing rather
# than defensive. Atlas gives every content Blob the role `original_file`, so a
# caption satisfies the PrimaryFilePresence test that ConfirmDepositJob waits on
# — attaching one first would let a deposit complete around captions alone, and
# Atlas builds the Work's METS structMap at completion, recording a preservation
# structure that omits the video. Waiting also puts this write after the deposit's
# own, so the two Blob writers do not race.
#
# Attach-only, like AddFileJob: no derivative enrichment runs, so the Work's
# thumbnail, poster and player are untouched by a caption upload.
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
