# frozen_string_literal: true

# Extracts a content document's body text and PATCHes it to the Work as derived
# full text (AtlasRb::Work.set_full_text → Atlas projects it onto the Work's
# all_text_timv Solr field, powering body-text search + the "Full Text Match"
# result snippet). The v2 counterpart to v1's pdftotext/Tika indexing — but in
# the right layer: Cerberus extracts (it has the tooling + staged bytes + jobs),
# Atlas stores + indexes (it owns Solr and durability across reindex).
#
# Called from IngestDispatch for native PDFs and plain text, and from
# PdfRenditionJob with the soffice-built PDF rendition (so Office docs reuse that
# single conversion rather than running soffice twice). Re-PATCHing is idempotent
# — a replace re-extracts and overwrites.
#
# Enrichment never fails a deposit (v1 parity): exhaust retries, log, move on.
class FullTextExtractionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, attempts: 3, wait: :polynomially_longer do |job, exception|
    Rails.logger.warn(
      "FullTextExtractionJob gave up for work #{job.arguments.first}: #{exception.class}: #{exception.message}"
    )
  end

  def perform(work_id, source_path)
    return unless File.exist?(source_path)

    text = extract(source_path)
    return if text.blank?

    AtlasRb::Work.set_full_text(work_id, text: text)
  end

  private

    def extract(source_path)
      mime = Marcel::MimeType.for(Pathname.new(source_path), name: File.basename(source_path))
      if mime == 'application/pdf'
        PdfText.call(source_path: source_path)
      elsif mime.start_with?('text/')
        File.read(source_path)
      end
    end
end
