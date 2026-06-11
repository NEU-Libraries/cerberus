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
# No derivative_widths pass through here: deposits get thumbnails only at
# upload time. Small/medium/large are opt-in download renditions chosen on
# the metadata page (DepositDerivativesJob), and per policy documents get
# thumbnails only, never S/M/L.
#
# Detection sniffs the staged file with Marcel rather than trusting a
# browser-supplied content type (absent in the loader path anyway). The
# `name:` hint is load-bearing for legacy .doc/.ppt — magic bytes alone
# read as application/x-ole-storage.
class IngestDispatch < ApplicationService
  CONVERTIBLE_MIME_TYPES = %w[
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.openxmlformats-officedocument.presentationml.slideshow
  ].freeze

  def initialize(work_id:, staged_path:, original_filename:, idempotency_key:)
    @work_id = work_id
    @staged_path = staged_path
    @original_filename = original_filename
    @idempotency_key = idempotency_key
  end

  def call
    if mime_type.start_with?('image/') || mime_type == 'application/pdf'
      IiifAssetsJob.perform_later(@work_id, @staged_path)
    elsif CONVERTIBLE_MIME_TYPES.include?(mime_type)
      PdfRenditionJob.perform_later(@work_id, @staged_path, rendition_key)
    end
    ContentCreationJob.perform_later(@work_id, @staged_path, @original_filename, @idempotency_key)
  end

  private

    def mime_type
      @mime_type ||= Marcel::MimeType.for(Pathname.new(@staged_path), name: @original_filename).to_s
    end

    # Derived (uuid_v5), not minted, so the rendition Blob converges on the
    # same Atlas idempotency key across Solid Queue retries AND a
    # re-dispatched loader row — same dedup story as the primary Blob's key.
    def rendition_key
      Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "cerberus:rendition:#{@idempotency_key}")
    end
end
