# frozen_string_literal: true

# Attaches a user-supplied binary to an existing Work as an additional Blob —
# the "Upload File" affordance on the Work show page. Attach-only by design: the
# file becomes a downloadable Blob (surfacing in the Downloads card) and nothing
# else runs. No derivative enrichment, so the Work's representative thumbnail,
# viewer, A/V player, and full-text index are left untouched — an added file is
# supplemental material, not a replacement for the Work's primary representation.
#
# The upload is staged to disk (UploadStaging) so the request can return before
# this streams the potentially multi-GB file into Atlas. Blob.create is
# idempotent on its idempotency_key, so a Solid Queue retry converges on the one
# Blob rather than attaching duplicates. The Work is already complete, so no
# Work.complete call is needed (unlike the deposit's ContentCreationJob).
class AddFileJob < ApplicationJob
  queue_as :default

  def perform(work_id, source_path, original_filename, idempotency_key)
    return unless File.exist?(source_path)

    AtlasRb::Blob.create(work_id, source_path, original_filename, idempotency_key: idempotency_key)
  end
end
