# frozen_string_literal: true

# Enriches an audio/video deposit so it plays in-browser: a poster frame (video)
# fed to the thumbnail pipeline, and — when the master's container isn't already
# browser-universal (e.g. H.264 in .mov) — a lossless `-c copy` MP4 rendition
# attached as an ordinary Blob (the PdfRenditionJob pattern). Codecs are already
# gated safe at deposit (Ffprobe), so this is pure container work, never an encode.
#
# Ordering + failure posture mirror PdfRenditionJob: convert first (the slow
# part), then raise WorkNotComplete until the primary writer (ContentCreationJob)
# has flipped the Work out of in_progress. Enrichment never fails a deposit — a
# bad input, a hung ffmpeg, or a never-completing Work exhausts retries, logs,
# and leaves the deposit intact (master present, no rendition, no poster).
class MediaRenditionJob < ApplicationJob
  queue_as :default

  class WorkNotComplete < StandardError; end

  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "MediaRenditionJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
  end
  # Declared after StandardError so it takes precedence (reverse-order matching).
  retry_on WorkNotComplete, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "MediaRenditionJob: work #{job.arguments.first} never completed — A/V rendition skipped"
    )
  end

  def perform(work_id, staged_path, rendition_key)
    return unless File.exist?(staged_path)
    unless MediaRemux.available?
      return Rails.logger.warn("MediaRenditionJob: ffmpeg not installed — A/V rendition skipped for work #{work_id}")
    end

    mime = Marcel::MimeType.for(Pathname.new(staged_path)).to_s
    poster_path = build_poster(work_id, staged_path) if mime.start_with?('video/')
    mp4_path = MediaRemux.to_mp4(staged_path, rendition_path(staged_path)) if MediaRemux.remux_needed?(mime)

    raise WorkNotComplete, "work #{work_id} is still in progress" if AtlasRb::Work.find(work_id).in_progress

    AtlasRb::Blob.create(work_id, mp4_path, File.basename(mp4_path), idempotency_key: rendition_key) if mp4_path
    # perform_now so the ambient acting NUID carries through (see ApplicationJob).
    IiifAssetsJob.perform_now(work_id, poster_path) if poster_path
  end

  private

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
