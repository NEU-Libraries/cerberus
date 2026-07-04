# frozen_string_literal: true

# Replaces the bytes behind an existing Blob with a freshly staged upload,
# non-destructively: Blob.update appends a new OCFL revision and the Blob NOID
# is preserved (prior versions stay retrievable via Blob.versions). Backgrounded
# like the deposit's ContentCreationJob so a multi-GB upload never blocks the
# request.
#
# After the primary bytes land, the type-routed *derivative* enrichment is
# re-dispatched (include_primary: false — IngestDispatch must NOT create a second
# primary Blob) so thumbnails / JP2 / PDF renditions track the new content rather
# than the superseded bytes. A fresh idempotency_key per replace means the
# rendition's derived key differs from the prior one, so Atlas regenerates rather
# than dedup-skipping.
class FileReplacementJob < ApplicationJob
  queue_as :default

  def perform(blob_noid, work_id, staged_path, original_filename, idempotency_key)
    return unless File.exist?(staged_path)

    AtlasRb::Blob.update(blob_noid, staged_path, idempotency_key: idempotency_key)
    IngestDispatch.call(work_id: work_id, staged_path: staged_path,
                        original_filename: original_filename,
                        idempotency_key: idempotency_key, include_primary: false)
  end
end
