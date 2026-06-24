# frozen_string_literal: true

# Re-derives a Blob's derivatives (thumbnails / JP2 / PDF rendition) from its
# *current* bytes. Used after a rollback: Blob.rollback reinstates a prior
# version server-side without sending bytes to Cerberus, but derivatives are
# computed from pixels, so they must be regenerated from a local copy of the
# reinstated content.
#
# Streams the current content to the same persistent uploads root the deposit
# path stages into (NOT a mktmpdir — the derivative jobs are themselves enqueued
# and read the file *after* this job returns, so it must outlive this process),
# then re-dispatches derivative-only enrichment (include_primary: false — the
# primary Blob already holds the reinstated bytes).
class FileDerivativeRefreshJob < ApplicationJob
  queue_as :default

  def perform(work_id, blob_noid)
    blob = AtlasRb::Blob.find(blob_noid)
    return if blob.nil?

    name = blob.filename.presence || blob_noid
    path = stage_current_content(work_id, blob_noid, name)
    IngestDispatch.call(work_id: work_id, staged_path: path, original_filename: name,
                        idempotency_key: SecureRandom.uuid, include_primary: false)
  end

  private

    def stage_current_content(work_id, blob_noid, name)
      dir = File.join(Rails.application.config.x.cerberus.uploads_root, work_id.to_s)
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, name)
      File.open(dest, 'wb') { |f| AtlasRb::Blob.content(blob_noid) { |chunk| f.write(chunk) } }
      dest
    end
end
