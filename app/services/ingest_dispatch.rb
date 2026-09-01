# frozen_string_literal: true

# Routes a staged upload to its post-upload enrichment jobs, and is the single
# home for "what does this file type get?" so the deposit and loader paths cannot
# drift. `include_primary:` and `complete_work:` are different facts, not two
# names for one — read docs/ingest.md before changing either.
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

  # rubocop:disable Metrics/ParameterLists -- all six are keywords, so there is no
  # positional-order hazard for the cop to protect against, and each names one
  # independent fact about the dispatch. Bundling them into an options object
  # would hide the two flags that callers actually vary.
  def initialize(work_id:, staged_path:, original_filename:, idempotency_key:, include_primary: true,
                 complete_work: true)
    @work_id = work_id
    @staged_path = staged_path
    @original_filename = original_filename
    @idempotency_key = idempotency_key
    @include_primary = include_primary
    @complete_work = complete_work
  end
  # rubocop:enable Metrics/ParameterLists

  def call
    if mime_type.start_with?('image/') || mime_type == 'application/pdf'
      IiifAssetsJob.perform_later(@work_id, @staged_path, refresh: refreshing?)
    elsif CONVERTIBLE_MIME_TYPES.include?(mime_type)
      PdfRenditionJob.perform_later(@work_id, @staged_path, rendition_key)
    elsif mime_type.start_with?('video/', 'audio/')
      MediaRenditionJob.perform_later(@work_id, @staged_path, rendition_key)
    end
    FullTextExtractionJob.perform_later(@work_id, @staged_path) if extractable_text?
    return unless @include_primary

    ContentCreationJob.perform_later(@work_id, @staged_path, @original_filename, @idempotency_key,
                                     complete_work: @complete_work)
  end

  private

    # The two conditions coincide by construction: the only callers that skip
    # the primary Blob are replace and rollback, and both are re-deriving the
    # assets of a Work that already has them. A separate flag would be a second
    # name for the same fact.
    def refreshing?
      !@include_primary
    end

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
