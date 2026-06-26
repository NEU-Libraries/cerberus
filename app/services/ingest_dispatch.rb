# frozen_string_literal: true

# Routes a staged upload to its post-upload enrichment jobs. The single
# home for "what does this file type get?" — shared by the single-file
# deposit (WorksController) and the XML loader (XmlIngestJob) so the two
# ingest paths can't drift:
#
# - image/*          → IiifAssetsJob (JP2 + thumbnail Delegates, as ever)
# - application/pdf  → IiifAssetsJob (MasterJp2 rasterizes page 1 via vips/poppler)
# - Word/PowerPoint  → PdfRenditionJob (LibreOffice → PDF rendition Blob,
#                      then thumbnails from the rendition's first page)
# - everything       → ContentCreationJob (the primary Blob — enrichment
#                      never gates or blocks it)
#
# Full text rides alongside, for body-text search + the "Full Text Match"
# snippet: native PDFs and plain text → FullTextExtractionJob here; Office
# docs get theirs from the PDF rendition instead (PdfRenditionJob enqueues
# it on the converted PDF, so soffice runs once).
#
# `include_primary:` controls that last branch. The deposit/loader paths leave
# it true (the primary Blob is created here). The admin "replace a file" path
# passes false: the primary bytes are written separately by Blob.update (NOID
# preserved), so only the type-routed *derivative* refresh is wanted here —
# never a second ContentCreationJob/Blob.create.
#
# No derivative_widths pass through here: deposits get thumbnails only at
# upload time. Small/medium/large are opt-in download renditions chosen on
# the metadata page (DepositDerivativesJob), and per policy documents get
# thumbnails only, never S/M/L.
#
# Detection sniffs the staged file with Marcel rather than trusting a
# browser-supplied content type (absent in the loader path anyway). Legacy
# Office files (.doc/.ppt) need a second step: their magic bytes only say
# "OLE container", and Marcel keeps the magic type because its hierarchy
# roots msword/ms-powerpoint under x-tika-msoffice, not x-ole-storage — so
# for those ambiguous container types the filename decides.
class IngestDispatch < ApplicationService
  CONVERTIBLE_MIME_TYPES = %w[
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.openxmlformats-officedocument.presentationml.slideshow
  ].freeze

  OLE_CONTAINER_TYPES = %w[
    application/x-ole-storage
    application/x-tika-msoffice
  ].freeze

  def initialize(work_id:, staged_path:, original_filename:, idempotency_key:, include_primary: true)
    @work_id = work_id
    @staged_path = staged_path
    @original_filename = original_filename
    @idempotency_key = idempotency_key
    @include_primary = include_primary
  end

  def call
    if mime_type.start_with?('image/') || mime_type == 'application/pdf'
      IiifAssetsJob.perform_later(@work_id, @staged_path)
    elsif CONVERTIBLE_MIME_TYPES.include?(mime_type)
      PdfRenditionJob.perform_later(@work_id, @staged_path, rendition_key)
    elsif mime_type.start_with?('video/', 'audio/')
      MediaRenditionJob.perform_later(@work_id, @staged_path, rendition_key)
    end
    FullTextExtractionJob.perform_later(@work_id, @staged_path) if extractable_text?
    return unless @include_primary

    ContentCreationJob.perform_later(@work_id, @staged_path, @original_filename, @idempotency_key)
  end

  private

    # Direct full-text candidates: native PDFs and plain text. Office docs are
    # excluded here — their text comes from the PDF rendition (PdfRenditionJob),
    # so soffice converts once.
    def extractable_text?
      mime_type == 'application/pdf' || mime_type.start_with?('text/')
    end

    def mime_type
      @mime_type ||= begin
        sniffed = Marcel::MimeType.for(Pathname.new(@staged_path), name: @original_filename).to_s
        OLE_CONTAINER_TYPES.include?(sniffed) ? Marcel::MimeType.for(name: @original_filename).to_s : sniffed
      end
    end

    # Derived (uuid_v5), not minted, so the rendition Blob converges on the
    # same Atlas idempotency key across Solid Queue retries AND a
    # re-dispatched loader row — same dedup story as the primary Blob's key.
    def rendition_key
      Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "cerberus:rendition:#{@idempotency_key}")
    end
end
