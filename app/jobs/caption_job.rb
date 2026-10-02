# frozen_string_literal: true

# Attaches a depositor's WebVTT file to a Work as the caption track for one
# language, replacing that language's caption rather than accumulating.
#
# The wait for the Work's primary file is load-bearing, not defensive: a caption
# also carries the role `original_file`, so attaching one first lets a deposit
# complete around captions alone and Atlas writes a METS structMap omitting the
# recording. See docs/derivatives.md.
class CaptionJob < ApplicationJob
  include PrimaryFilePresence

  queue_as :default

  class PrimaryFileMissing < StandardError; end

  retry_on PrimaryFileMissing, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "CaptionJob: work #{job.arguments.first} never received its primary file — captions not attached"
    )
  end

  # A Blob write bumps the Work's optimistic lock, so this can lose a race with
  # the deposit's own finalization even after the wait above.
  retry_on AtlasRb::StaleResourceError, attempts: 5, wait: :polynomially_longer

  # `track` is { 'language', 'track_label' }. The English default covers a job
  # queued before the form asked for a language.
  def perform(work_id, staged_path, original_filename, idempotency_key, track = {})
    return unless File.exist?(staged_path)
    raise PrimaryFileMissing, "work #{work_id} has no primary file yet" unless primary_file?(work_id)

    language = track['language'] || CaptionTrack::LANGUAGE
    write = { language: language, track_label: track['track_label'] || CaptionTrack::LABEL,
              idempotency_key: idempotency_key }
    existing = CaptionTrack.for_language(AtlasRb::Work.assets(work_id), language)

    if existing
      AtlasRb::Blob.update(existing.noid, staged_path, **write)
    else
      AtlasRb::Blob.create(work_id, staged_path, original_filename, **write)
    end
  end
end
