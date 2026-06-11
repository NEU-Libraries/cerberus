# frozen_string_literal: true

# Enriches a Word/PowerPoint deposit with a PDF rendition (v1 parity:
# thesis.docx → thesis.pdf attached alongside the original) and seeds the
# Work's thumbnails from the rendition's first page.
#
# Ordering: ContentCreationJob owns the primary Blob and flips the Work
# out of in_progress via Work.complete. Rather than racing it with a
# second concurrent Blob writer, this job converts first (the slow part —
# overlapping the wait for free) and then raises WorkNotComplete until the
# primary writer has finished — the ThumbnailNotReady idiom from
# DepositDerivativesJob.
#
# Failure posture matches v1: enrichment never fails a deposit. A corrupt
# document, a hung soffice (killed at 120s by bin/soffice-timeout), or a
# never-completing Work all exhaust their retries, log, and leave the
# deposit intact — primary file present, no rendition, no thumbnail.
class PdfRenditionJob < ApplicationJob
  queue_as :default

  class WorkNotComplete < StandardError; end

  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "PdfRenditionJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
  end
  # Declared after StandardError so it takes precedence (ActiveJob matches
  # rescue handlers in reverse declaration order). ~16 minutes of cover.
  retry_on WorkNotComplete, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "PdfRenditionJob: work #{job.arguments.first} never completed — PDF rendition skipped"
    )
  end

  def perform(work_id, staged_path, rendition_key)
    return unless File.exist?(staged_path)
    unless WordToPdf.available?
      return Rails.logger.warn("PdfRenditionJob: soffice not installed — rendition skipped for work #{work_id}")
    end

    pdf_path = rendition_path(staged_path)
    # The rendition lives next to the staged original (same lifecycle), so a
    # retry that already converted skips straight to the attach.
    WordToPdf.call(source_path: staged_path, target_path: pdf_path) unless File.exist?(pdf_path)

    raise WorkNotComplete, "work #{work_id} is still in progress" if AtlasRb::Work.find(work_id).in_progress

    AtlasRb::Blob.create(work_id, pdf_path, File.basename(pdf_path), idempotency_key: rendition_key)
    # perform_now so the ambient acting NUID carries through (see ApplicationJob).
    IiifAssetsJob.perform_now(work_id, pdf_path)
  end

  private

    def rendition_path(staged_path)
      File.join(File.dirname(staged_path), "#{File.basename(staged_path, '.*')}.pdf")
    end
end
