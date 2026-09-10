# frozen_string_literal: true

# Enriches a Word/PowerPoint deposit with a PDF rendition and seeds the Work's
# thumbnails from its first page. Converts first, THEN waits for the primary
# Blob, so it never races ContentCreationJob. The wait keys on the artifact — an
# asset whose role is `original_file` — never on the Work's in_progress flag,
# which reads as equivalent and is not. See docs/downloads.md.
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
  # rescue handlers in reverse declaration order).
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
    # Retry-safe: an attempt that already converted skips to the attach.
    WordToPdf.call(source_path: staged_path, target_path: pdf_path) unless File.exist?(pdf_path)

    raise PrimaryFileMissing, "work #{work_id} has no primary file yet" unless primary_file?(work_id)

    AtlasRb::Blob.create(work_id, pdf_path, File.basename(pdf_path), idempotency_key: rendition_key)
    # perform_now so the ambient acting NUID carries through (see ApplicationJob).
    IiifAssetsJob.perform_now(work_id, pdf_path)
    FullTextExtractionJob.perform_later(work_id, pdf_path)
    IncompleteFlag.clear(work_id)
  end

  private

    def rendition_path(staged_path)
      File.join(File.dirname(staged_path), "#{File.basename(staged_path, '.*')}.pdf")
    end
end
