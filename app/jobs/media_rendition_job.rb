# frozen_string_literal: true

# Enriches an audio/video deposit so it plays in-browser: when the original's
# container isn't already browser-universal (e.g. H.264 in .mov), a lossless
# `-c copy` MP4 rendition attached as an ordinary Blob (the PdfRenditionJob
# pattern). Codecs are already gated safe at deposit (Ffprobe), so this is pure
# container work, never an encode. It extracts no poster frame: a Work without a
# depositor-supplied poster shows the placeholder mark (see docs/derivatives.md).
#
# Ordering + failure posture mirror PdfRenditionJob: convert first (the slow
# part), then wait for the primary writer (ContentCreationJob) to land its Blob,
# keyed on the artifact rather than on the Work's in_progress flag — see
# PdfRenditionJob for why the flag is the wrong signal. Enrichment never fails a
# deposit — a bad input, a hung ffmpeg, or a primary Blob that never lands
# exhausts retries, logs, and leaves the deposit intact (original present, no
# rendition).
class MediaRenditionJob < ApplicationJob
  include PrimaryFilePresence

  queue_as :default

  class PrimaryFileMissing < StandardError; end

  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "MediaRenditionJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
    IncompleteFlag.set(job.arguments.first, nuid: job.current_nuid, reason: IncompleteReasons::MEDIA_RENDITION)
  end
  # Declared after StandardError so it takes precedence (reverse-order matching).
  retry_on PrimaryFileMissing, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "MediaRenditionJob: work #{job.arguments.first} never received its primary file — A/V rendition skipped"
    )
    IncompleteFlag.set(job.arguments.first, nuid: job.current_nuid, reason: IncompleteReasons::MEDIA_RENDITION)
  end

  # refresh: a replace or revert, whose Work already has an MP4 rendition.
  def perform(work_id, staged_path, rendition_key, refresh: false)
    return unless File.exist?(staged_path)
    unless MediaRemux.available?
      return Rails.logger.warn("MediaRenditionJob: ffmpeg not installed — A/V rendition skipped for work #{work_id}")
    end

    mime = Marcel::MimeType.for(Pathname.new(staged_path)).to_s
    mp4_path = MediaRemux.to_mp4(staged_path, rendition_path(staged_path)) if MediaRemux.remux_needed?(mime)

    attach(work_id, mp4_path, rendition_key, refresh: refresh)
  end

  private

    # Attach the rendition once the primary Blob is there — deferring to
    # ContentCreationJob, exactly like PdfRenditionJob.
    def attach(work_id, mp4_path, rendition_key, refresh:)
      raise PrimaryFileMissing, "work #{work_id} has no primary file yet" unless primary_file?(work_id)

      attach_mp4(work_id, mp4_path, rendition_key, refresh: refresh) if mp4_path
      IncompleteFlag.clear(work_id)
    end

    # A replace or revert updates the Work's one MP4 rather than adding another,
    # as PdfRenditionJob does for its PDF. A Blob delete is admin-only in Atlas,
    # and this job runs as whoever replaced the file.
    def attach_mp4(work_id, mp4_path, rendition_key, refresh:)
      existing = RenditionAsset.for(AtlasRb::Work.file_sets(work_id), mime_types: RenditionAsset::MP4) if refresh
      if existing
        AtlasRb::Blob.update(existing['noid'], mp4_path, idempotency_key: rendition_key)
      else
        AtlasRb::Blob.create(work_id, mp4_path, File.basename(mp4_path), idempotency_key: rendition_key)
      end
    end

    def rendition_path(staged_path)
      File.join(File.dirname(staged_path), "#{File.basename(staged_path, '.*')}.mp4")
    end
end
