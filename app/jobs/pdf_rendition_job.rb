# frozen_string_literal: true

# Enriches a Word/PowerPoint deposit with a PDF rendition (v1 parity:
# thesis.docx → thesis.pdf attached alongside the original) and seeds the
# Work's thumbnails from the rendition's first page.
#
# Ordering: ContentCreationJob owns the primary Blob. Rather than racing it with
# a second concurrent Blob writer, this job converts first (the slow part —
# overlapping the wait for free) and then waits for that primary Blob to appear —
# the ServiceNotReady idiom from DepositDerivativesJob.
#
# The wait keys on the ARTIFACT — an asset whose role is `original_file` — because
# that is the real precondition. Keying it on the Work's in_progress flag instead
# reads as equivalent and is not: that flag means "no depositor has confirmed this
# deposit", which an abandoned deposit never does, so a flag-based wait would
# strand the rendition on a human rather than on the writer it actually races.
#
# Failure posture matches v1: enrichment never fails a deposit. A corrupt
# document, a hung soffice (killed at 120s by bin/soffice-timeout), or a primary
# Blob that never lands all exhaust their retries, log, and leave the deposit
# intact — primary file present, no rendition, no thumbnail.
class PdfRenditionJob < ApplicationJob
  include PrimaryFilePresence

  queue_as :default

  class PrimaryFileMissing < StandardError; end

  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "PdfRenditionJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
    IncompleteFlag.set(job.arguments.first, nuid: job.current_nuid, reason: IncompleteReasons::PDF_RENDITION)
  end
  # Declared after StandardError so it takes precedence (ActiveJob matches
  # rescue handlers in reverse declaration order). ~16 minutes of cover.
  retry_on PrimaryFileMissing, attempts: 6, wait: :polynomially_longer do |job, _exception|
    Rails.logger.warn(
      "PdfRenditionJob: work #{job.arguments.first} never received its primary file — PDF rendition skipped"
    )
    IncompleteFlag.set(job.arguments.first, nuid: job.current_nuid, reason: IncompleteReasons::PDF_RENDITION)
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

    raise PrimaryFileMissing, "work #{work_id} has no primary file yet" unless primary_file?(work_id)

    AtlasRb::Blob.create(work_id, pdf_path, File.basename(pdf_path), idempotency_key: rendition_key)
    # perform_now so the ambient acting NUID carries through (see ApplicationJob).
    IiifAssetsJob.perform_now(work_id, pdf_path)
    # Office docs get their full text from this rendition (so soffice ran once).
    FullTextExtractionJob.perform_later(work_id, pdf_path)
    IncompleteFlag.clear(work_id)
  end

  private

    def rendition_path(staged_path)
      File.join(File.dirname(staged_path), "#{File.basename(staged_path, '.*')}.pdf")
    end
end
