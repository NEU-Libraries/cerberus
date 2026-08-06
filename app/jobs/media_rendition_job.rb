# frozen_string_literal: true

# Enriches an audio/video deposit so it plays in-browser: a poster frame (video)
# fed to the thumbnail pipeline, and — when the master's container isn't already
# browser-universal (e.g. H.264 in .mov) — a lossless `-c copy` MP4 rendition
# attached as an ordinary Blob (the PdfRenditionJob pattern). Codecs are already
# gated safe at deposit (Ffprobe), so this is pure container work, never an encode.
#
# Ordering + failure posture mirror PdfRenditionJob: convert first (the slow
# part), then wait for the primary writer (ContentCreationJob) to land its Blob,
# keyed on the artifact rather than on the Work's in_progress flag — see
# PdfRenditionJob for why the flag is the wrong signal. Enrichment never fails a
# deposit — a bad input, a hung ffmpeg, or a primary Blob that never lands
# exhausts retries, logs, and leaves the deposit intact (master present, no
# rendition, no poster).
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

  def perform(work_id, staged_path, rendition_key)
    return unless File.exist?(staged_path)
    unless MediaRemux.available?
      return Rails.logger.warn("MediaRenditionJob: ffmpeg not installed — A/V rendition skipped for work #{work_id}")
    end

    mime = Marcel::MimeType.for(Pathname.new(staged_path)).to_s
    poster_path = build_poster(work_id, staged_path) if mime.start_with?('video/')
    mp4_path = MediaRemux.to_mp4(staged_path, rendition_path(staged_path)) if MediaRemux.remux_needed?(mime)

    attach(work_id, mp4_path, poster_path, rendition_key)
  end

  private

    # Attach the rendition + poster once the primary Blob is there — deferring to
    # ContentCreationJob, exactly like PdfRenditionJob.
    def attach(work_id, mp4_path, poster_path, rendition_key)
      raise PrimaryFileMissing, "work #{work_id} has no primary file yet" unless primary_file?(work_id)

      AtlasRb::Blob.create(work_id, mp4_path, File.basename(mp4_path), idempotency_key: rendition_key) if mp4_path
      # perform_now so the ambient acting NUID carries through (see ApplicationJob).
      IiifAssetsJob.perform_now(work_id, poster_path) if poster_path
      IncompleteFlag.clear(work_id)
    end

    def rendition_path(staged_path)
      File.join(File.dirname(staged_path), "#{File.basename(staged_path, '.*')}.mp4")
    end

    # Best-effort: a poster failure leaves the work without a generated frame
    # (it falls back to the type icon) but never aborts the rendition.
    def build_poster(work_id, staged_path)
      path = File.join(File.dirname(staged_path), "#{File.basename(staged_path, '.*')}-poster.jpg")
      MediaRemux.poster(staged_path, path)
      path
    rescue StandardError => e
      Rails.logger.warn("MediaRenditionJob: poster extraction failed for work #{work_id} (#{e.message})")
      nil
    end
end
