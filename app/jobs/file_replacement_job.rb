# frozen_string_literal: true

# Replaces the bytes behind an existing Blob with a freshly staged upload,
# non-destructively: Blob.update appends a new OCFL revision and the Blob NOID
# is preserved (prior versions stay retrievable via Blob.versions). Backgrounded
# like the deposit's ContentCreationJob so a multi-GB upload never blocks the
# request.
#
# The upload's own filename goes with the bytes, so each revision records the
# name it was deposited under and the version table can show it. The type guard
# in Admin::FilesController keeps that name the same type as the one it replaces.
#
# After the primary bytes land, the type-routed *derivative* enrichment is
# re-dispatched (include_primary: false — IngestDispatch must NOT create a second
# primary Blob) so thumbnails / IIIF TIFFs / PDF renditions track the new content rather
# than the superseded bytes. A fresh idempotency_key per replace means the
# rendition's derived key differs from the prior one, so Atlas regenerates rather
# than dedup-skipping.
class FileReplacementJob < ApplicationJob
  queue_as :default

  def perform(blob_noid, work_id, staged_path, original_filename, idempotency_key)
    return unless File.exist?(staged_path)

    AtlasRb::Blob.update(blob_noid, staged_path, original_filename: original_filename,
                                                 idempotency_key:   idempotency_key)
    IngestDispatch.call(work_id: work_id, staged_path: staged_path,
                        original_filename: original_filename,
                        idempotency_key: idempotency_key, include_primary: false)
  end
end
